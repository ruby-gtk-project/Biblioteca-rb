# frozen_string_literal: true

require "doc_index"
require "fileutils"
require "json"
require "tmpdir"

# Not a parity test: upstream Biblioteca has no test suite (see TEST_PARITY.md).
# These pin lib/doc_index.rb, a port of build-aux/build-index.js, over a
# gi-docgen index.json fixture. Everything the sidebar shows and everything the
# search matches against comes out of these three mappings, and nineteen of the
# twenty symbol kinds have a page-name rule of their own.
RSpec.describe DocIndex, :extra do
  # One symbol of every kind gi-docgen emits, with the fields each kind's rules
  # read: `ctype` for types, `ident` for callables, `type_name` for members,
  # `struct_for` for a class method, `href` for extra documentation.
  def symbols
    [
      { "type" => "class", "name" => "Widget", "ctype" => "GtkWidget" },
      { "type" => "method", "name" => "show", "type_name" => "Widget", "ident" => "gtk_widget_show" },
      { "type" => "property", "name" => "visible", "type_name" => "Widget" },
      { "type" => "signal", "name" => "destroy", "type_name" => "Widget" },
      { "type" => "vfunc", "name" => "measure", "type_name" => "Widget" },
      { "type" => "ctor", "name" => "new", "type_name" => "Widget", "ident" => "gtk_widget_new" },
      {
        "type"       => "class_method",
        "name"       => "install_action",
        "struct_for" => "Widget",
        "ident"      => "gtk_widget_class_install_action",
      },
      {
        "type"      => "type_func",
        "name"      => "get_type",
        "type_name" => "Widget",
        "ident"     => "gtk_widget_get_type",
      },
      { "type" => "interface", "name" => "Buildable", "ctype" => "GtkBuildable" },
      { "type" => "record", "name" => "Border", "ctype" => "GtkBorder" },
      { "type" => "alias", "name" => "Allocation", "ctype" => "GtkAllocation" },
      { "type" => "enum", "name" => "Align", "ctype" => "GtkAlign" },
      { "type" => "bitfield", "name" => "StateFlags", "ctype" => "GtkStateFlags" },
      { "type" => "domain", "name" => "BuilderError", "ctype" => "GtkBuilderError" },
      { "type" => "callback", "name" => "TickCallback", "ctype" => "GtkTickCallback" },
      { "type" => "constant", "name" => "PRIORITY_RESIZE", "ident" => "GTK_PRIORITY_RESIZE" },
      { "type" => "function", "name" => "init", "ident" => "gtk_init" },
      { "type" => "function_macro", "name" => "CHECK_VERSION", "ident" => "GTK_CHECK_VERSION" },
      { "type" => "content", "name" => "Getting Started", "href" => "getting_started.html" },
    ]
  end

  # The fixture tree, built once: a gtk4 library with every symbol kind, a
  # deprecated atk library that must be skipped, and a directory with no
  # index.json that must be skipped too.
  around do |example|
    Dir.mktmpdir("doc-index-spec") do |root|
      @root = root
      write_library(
        "gtk4",
        "Gtk",
        "4.0",
        symbols,
      )
      write_library(
        "atk",
        "Atk",
        "1.0",
        [],
      )
      FileUtils.mkdir_p(File.join(root, "not-a-library"))
      example.run
    end
  end

  def write_library(directory, namespace, version, symbols)
    File.join(@root, directory).tap do |path|
      FileUtils.mkdir_p(path)
      File.write(
        File.join(path, "index.json"),
        JSON.generate({ "meta" => { "ns" => namespace, "version" => version }, "symbols" => symbols }),
      )
    end
  end

  def index = described_class.new(root: @root)
  def gtk = index.docs.fetch(0)
  def section(title) = gtk.fetch("children").find { |child| child["name"] == title }
  def leaf(title) = section(title).fetch("children").fetch(0)

  def member(section_title, subsection_title)
    section(section_title).fetch("children").fetch(0)
                          .fetch("children").find { |child| child["name"] == subsection_title }
                          .fetch("children").fetch(0)
  end

  describe "library selection" do
    it "indexes only the libraries with an index.json that are not ignored" do
      expect(index.docs.map { |doc| doc["name"] }).to eq(["Gtk-4.0"])
    end

    it "names the namespace from meta.ns and meta.version" do
      expect(gtk.values_at("name", "tag", "search_name"))
        .to eq(["Gtk-4.0", "namespace", "Gtk-4.0"])
    end

    it "points the namespace at the library's index.html" do
      expect(gtk.fetch("uri")).to eq("file://#{@root}/gtk4/index.html")
    end

    it "reports the position of Gtk-4.0 as the start index" do
      expect(index.start_index).to eq(0)
    end

    it "reports -1 when there are no GTK docs" do
      Dir.mktmpdir("doc-index-empty") do |empty|
        expect(described_class.new(root: empty).start_index).to eq(-1)
      end
    end
  end

  describe "section layout" do
    it "emits one section per symbol kind present, sorted by name" do
      expect(gtk.fetch("children").map { |child| child["name"] })
        .to eq(
          [
            "Addition Documentation", "Aliases", "Bitfields", "Callbacks", "Classes",
            "Constants", "Enumerations", "Error Domains", "Function Macros", "Functions",
            "Interfaces", "Structs"
          ],
        )
    end

    it "anchors each section on the library index" do
      expect(section("Classes").fetch("uri")).to eq("file://#{@root}/gtk4/index.html#classes")
    end

    it "nests a class's members under the class, sorted by subsection name" do
      expect(leaf("Classes").fetch("children").map { |child| child["name"] })
        .to eq(
          [
            "Class Methods", "Constructors", "Functions", "Instance Methods",
            "Properties", "Signals", "Virtual Methods"
          ],
        )
    end

    it "anchors each subsection on the owning type's page" do
      expect(leaf("Classes").fetch("children").first.fetch("uri"))
        .to eq("file://#{@root}/gtk4/class.Widget.html#class-methods")
    end

    it "gives a member-less required type an empty children list" do
      expect(leaf("Error Domains").fetch("children")).to eq([])
    end
  end

  describe "the page each symbol kind links to" do
    it "maps the namespace-level kinds" do
      expect(
        {
          "Aliases"                => leaf("Aliases").fetch("uri"),
          "Bitfields"              => leaf("Bitfields").fetch("uri"),
          "Callbacks"              => leaf("Callbacks").fetch("uri"),
          "Classes"                => leaf("Classes").fetch("uri"),
          "Constants"              => leaf("Constants").fetch("uri"),
          "Enumerations"           => leaf("Enumerations").fetch("uri"),
          "Error Domains"          => leaf("Error Domains").fetch("uri"),
          "Function Macros"        => leaf("Function Macros").fetch("uri"),
          "Functions"              => leaf("Functions").fetch("uri"),
          "Interfaces"             => leaf("Interfaces").fetch("uri"),
          "Structs"                => leaf("Structs").fetch("uri"),
          "Addition Documentation" => leaf("Addition Documentation").fetch("uri"),
        },
      ).to eq(
        {
          "Aliases"                => "file://#{@root}/gtk4/alias.Allocation.html",
          "Bitfields"              => "file://#{@root}/gtk4/flags.StateFlags.html",
          "Callbacks"              => "file://#{@root}/gtk4/callback.TickCallback.html",
          "Classes"                => "file://#{@root}/gtk4/class.Widget.html",
          "Constants"              => "file://#{@root}/gtk4/const.PRIORITY_RESIZE.html",
          "Enumerations"           => "file://#{@root}/gtk4/enum.Align.html",
          "Error Domains"          => "file://#{@root}/gtk4/error.BuilderError.html",
          "Function Macros"        => "file://#{@root}/gtk4/func.CHECK_VERSION.html",
          "Functions"              => "file://#{@root}/gtk4/func.init.html",
          "Interfaces"             => "file://#{@root}/gtk4/iface.Buildable.html",
          "Structs"                => "file://#{@root}/gtk4/struct.Border.html",
          # `content` is the one kind that carries its own href.
          "Addition Documentation" => "file://#{@root}/gtk4/getting_started.html",
        },
      )
    end

    it "qualifies a member's page by its owning type" do
      expect(
        {
          "Instance Methods" => member("Classes", "Instance Methods").fetch("uri"),
          "Properties"       => member("Classes", "Properties").fetch("uri"),
          "Signals"          => member("Classes", "Signals").fetch("uri"),
          "Virtual Methods"  => member("Classes", "Virtual Methods").fetch("uri"),
          "Constructors"     => member("Classes", "Constructors").fetch("uri"),
          "Functions"        => member("Classes", "Functions").fetch("uri"),
          # class_method names its owner in struct_for, not type_name.
          "Class Methods"    => member("Classes", "Class Methods").fetch("uri"),
        },
      ).to eq(
        {
          "Instance Methods" => "file://#{@root}/gtk4/method.Widget.show.html",
          "Properties"       => "file://#{@root}/gtk4/property.Widget.visible.html",
          "Signals"          => "file://#{@root}/gtk4/signal.Widget.destroy.html",
          "Virtual Methods"  => "file://#{@root}/gtk4/vfunc.Widget.measure.html",
          "Constructors"     => "file://#{@root}/gtk4/ctor.Widget.new.html",
          "Functions"        => "file://#{@root}/gtk4/type_func.Widget.get_type.html",
          "Class Methods"    => "file://#{@root}/gtk4/class_method.Widget.install_action.html",
        },
      )
    end
  end

  describe "the tag shown as a pill beside a search result" do
    it "relabels the seven kinds whose gi-docgen name is not the word a reader expects" do
      expect(
        {
          "method"         => member("Classes", "Instance Methods").fetch("tag"),
          "class_method"   => member("Classes", "Class Methods").fetch("tag"),
          "type_func"      => member("Classes", "Functions").fetch("tag"),
          "ctor"           => member("Classes", "Constructors").fetch("tag"),
          "content"        => leaf("Addition Documentation").fetch("tag"),
          "domain"         => leaf("Error Domains").fetch("tag"),
          "function_macro" => leaf("Function Macros").fetch("tag"),
          "record"         => leaf("Structs").fetch("tag"),
        },
      ).to eq(
        {
          "method"         => "method",
          "class_method"   => "method",
          "type_func"      => "function",
          "ctor"           => "constructor",
          "content"        => "additional",
          "domain"         => "error",
          "function_macro" => "macro",
          "record"         => "struct",
        },
      )
    end

    it "passes every other kind through unchanged" do
      expect(
        [
          leaf("Classes").fetch("tag"),
          leaf("Interfaces").fetch("tag"),
          leaf("Aliases").fetch("tag"),
          leaf("Enumerations").fetch("tag"),
          leaf("Bitfields").fetch("tag"),
          leaf("Callbacks").fetch("tag"),
          leaf("Constants").fetch("tag"),
          leaf("Functions").fetch("tag"),
          member("Classes", "Properties").fetch("tag"),
          member("Classes", "Signals").fetch("tag"),
          member("Classes", "Virtual Methods").fetch("tag"),
        ],
      ).to eq(
        %w[class interface alias enum bitfield callback constant function property signal vfunc],
      )
    end
  end

  describe "the name the search matches against" do
    it "uses the C type name for a type" do
      expect(
        [
          leaf("Classes").fetch("search_name"),
          leaf("Interfaces").fetch("search_name"),
          leaf("Structs").fetch("search_name"),
          leaf("Aliases").fetch("search_name"),
          leaf("Enumerations").fetch("search_name"),
          leaf("Bitfields").fetch("search_name"),
          leaf("Callbacks").fetch("search_name"),
          leaf("Error Domains").fetch("search_name"),
        ],
      ).to eq(
        %w[
          GtkWidget GtkBuildable GtkBorder GtkAllocation
          GtkAlign GtkStateFlags GtkTickCallback GtkBuilderError
        ],
      )
    end

    it "uses the C identifier for a callable" do
      expect(
        [
          leaf("Functions").fetch("search_name"),
          leaf("Function Macros").fetch("search_name"),
          leaf("Constants").fetch("search_name"),
          member("Classes", "Instance Methods").fetch("search_name"),
          member("Classes", "Class Methods").fetch("search_name"),
          member("Classes", "Constructors").fetch("search_name"),
          member("Classes", "Functions").fetch("search_name"),
        ],
      ).to eq(
        %w[
          gtk_init GTK_CHECK_VERSION GTK_PRIORITY_RESIZE gtk_widget_show
          gtk_widget_class_install_action gtk_widget_new gtk_widget_get_type
        ],
      )
    end

    it "qualifies a property, a signal and a virtual method by their owner" do
      expect(
        [
          member("Classes", "Properties").fetch("search_name"),
          member("Classes", "Signals").fetch("search_name"),
          member("Classes", "Virtual Methods").fetch("search_name"),
        ],
      ).to eq(["GtkWidget:visible", "GtkWidget::destroy", "GtkWidget.measure"])
    end

    it "uses the page name for extra documentation" do
      expect(leaf("Addition Documentation").fetch("search_name")).to eq("Getting Started")
    end
  end

  describe ".read and #write" do
    it "round-trips the index through doc-index.json" do
      Dir.mktmpdir("doc-index-write") do |dir|
        index.write(dir).then do |path|
          expect([File.basename(path), described_class.read(path)])
            .to eq([described_class::FILENAME, index.to_h])
        end
      end
    end

    it "returns nil when there is no doc-index.json to read" do
      expect(described_class.read(File.join(@root, "absent.json"))).to be_nil
    end
  end
end
