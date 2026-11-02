# frozen_string_literal: true

require 'json'
require 'fileutils'

# DocIndex builds doc-index.json, the file the sidebar's whole tree is read
# from.
#
# Ported from upstream's build-aux/build-index.js, which runs at build time
# under gjs and writes the result into pkgdatadir. It walks a documentation
# root, reads the `index.json` gi-docgen leaves beside every library's
# generated HTML, and turns each one into a namespace node with sections
# ("Classes", "Functions", …), subsections under the types that have members
# ("Constructors", "Instance Methods", "Properties", "Signals", …), and a leaf
# per symbol carrying the name, the symbol kind and the file:// URI of its
# page.
#
# The documentation root is a constructor argument, defaulting to the first of
# DEFAULT_ROOTS that exists. Upstream hardcodes /app/share/doc because it only
# ever runs inside its Flatpak build; a checkout on a developer's machine has
# the GNOME docs under /usr/share/doc instead.
#
# Every other consumer of that root derives it from here rather than spelling
# /app out again: Window::FALLBACK_DOC_ROOT is DEFAULT_ROOTS.first, and the uri
# a new tab opens on is Sidebar#start_uri, read out of the built index
# (lib/window.rb#default_uri).
#
# Libraries are read one after another. Upstream reads them concurrently with
# promises; nothing here waits on anything but the filesystem, and the
# resulting index is identical.
#
# Upstream's ordering is reproduced exactly: the tree is built in SECTION_TYPES
# order and then sorted by name at every level, which is what actually decides
# what the sidebar shows.
class DocIndex
  # Upstream's /app/share/doc, then the paths a non-Flatpak install uses.
  DEFAULT_ROOTS = [
    '/app/share/doc',
    '/usr/share/doc',
    '/usr/local/share/doc',
  ].freeze

  # Deprecated libraries upstream refuses to index.
  IGNORED_LIBRARIES = %w[
    atk
    libhandy-1
    webkit2gtk-4.1
    webkit2gtk-web-extension-4.1
    javascriptcoregtk-4.1
    gcr-3
    gcr-ui-3
    gck-1
  ].freeze

  # gi-docgen symbol type => [section heading, the anchor on index.html].
  SECTION_TYPES = {
    'class'          => ['Classes', '#classes'],
    'content'        => ['Addition Documentation', '#extra'],
    'interface'      => ['Interfaces', '#interfaces'],
    'record'         => ['Structs', '#structs'],
    'alias'          => ['Aliases', '#aliases'],
    'enum'           => ['Enumerations', '#enums'],
    'bitfield'       => ['Bitfields', '#bitfields'],
    'function'       => ['Functions', '#functions'],
    'function_macro' => ['Function Macros', '#function_macros'],
    'domain'         => ['Error Domains', '#domains'],
    'callback'       => ['Callbacks', '#callbacks'],
    'constant'       => ['Constants', '#constants'],
  }.freeze

  # The same, for the members grouped under a single type's page.
  SUBSECTION_TYPES = {
    'ctor'         => ['Constructors', '#constructors'],
    'type_func'    => ['Functions', '#type-functions'],
    'method'       => ['Instance Methods', '#methods'],
    'property'     => ['Properties', '#properties'],
    'signal'       => ['Signals', '#signals'],
    'class_method' => ['Class Methods', '#class-methods'],
    'vfunc'        => ['Virtual Methods', '#virtual-methods'],
  }.freeze

  # Only these four kinds of symbol get their members nested underneath them.
  REQUIRED = %w[class interface record domain].freeze

  # The namespace the sidebar opens on.
  START_NAMESPACE = 'Gtk-4.0'

  # The filename upstream writes into pkgdatadir and Sidebar reads back.
  FILENAME = 'doc-index.json'

  def self.default_root
    DEFAULT_ROOTS.find { |path| Dir.exist?(path) }
  end

  # Reads a doc-index.json written by an earlier run (or by upstream's own
  # build step) back into the { "start_index" =>, "docs" => } shape the sidebar
  # wants. Returns nil when there is no such file, which is how the sidebar
  # knows to build one.
  def self.read(path)
    if File.exist?(path)
      JSON.parse(File.read(path))
    end
  rescue JSON::ParserError => e
    warn "Error parsing #{path}: #{e.message}"
    nil
  end

  def initialize(root: nil)
    @root = root || self.class.default_root
  end

  def root = @root

  # Every indexable library under the root, sorted, with its whole tree built.
  def docs
    @docs ||= scan_libraries.tap { |index| sort_index(index) }
  end

  # The position of Gtk-4.0 in `docs`, which is the row the sidebar selects on
  # startup. -1 when the GTK docs are not installed, which is what
  # Array#findIndex gives upstream too.
  def start_index = docs.index { |doc| doc['name'] == START_NAMESPACE } || -1

  def to_h
    {
      'start_index' => start_index,
      'docs'        => docs,
    }
  end

  # Writes doc-index.json into `dir`, creating it if needed, and hands back the
  # path written.
  def write(dir)
    File.join(dir, FILENAME).tap do |path|
      FileUtils.mkdir_p(dir)
      File.write(path, JSON.generate(to_h))
    end
  end

  private

    def scan_libraries
      if @root.nil? || !Dir.exist?(@root)
        []
      else
        Dir.children(@root)
           .select { |name| library?(name) }
           .filter_map { |name| load_library(File.join(@root, name)) }
      end
    end

    def library?(name)
      Dir.exist?(File.join(@root, name)) && !IGNORED_LIBRARIES.include?(name)
    end

    # A directory with no index.json is not a gi-docgen output tree; upstream
    # swallows the NOT_FOUND and moves on.
    def load_library(directory)
      File.join(directory, 'index.json').then do |json_path|
        if File.exist?(json_path)
          namespace_node(JSON.parse(File.read(json_path)), directory)
        end
      end
    rescue JSON::ParserError => e
      warn "Error parsing #{directory}/index.json: #{e.message}"
      nil
    end

    def namespace_node(index, directory)
      "#{index.dig('meta', 'ns')}-#{index.dig('meta', 'version')}".then do |namespace|
        {
          'name'        => namespace,
          'tag'         => 'namespace',
          'search_name' => namespace,
          'uri'         => file_uri(File.join(directory, 'index.html')),
          'children'    => children_for(index, directory),
        }
      end
    end

    # Buckets every symbol into its section, or — when it belongs to a type
    # rather than to the namespace — into that type's subsection, then turns
    # the non-empty buckets into nodes.
    def children_for(index, directory)
      sections = SECTION_TYPES.keys.to_h { |type| [type, []] }
      subsections = {}

      index.dig('meta', 'ns').to_s.then do |namespace|
        index.fetch('symbols', []).each do |symbol|
          bucket_for(symbol, sections, subsections)
            &.push(leaf_for(symbol, directory, namespace))
        end
      end

      attach_subsections(subsections, sections)
      section_nodes(sections, file_uri(File.join(directory, 'index.html')))
    end

    # A symbol whose type names a section goes there. Otherwise it belongs to a
    # type: `class_method` names its owner in `struct_for` rather than in
    # `type_name`, which is the one irregular case.
    def bucket_for(symbol, sections, subsections)
      owner = symbol['struct_for'] || symbol['type_name']

      if sections.key?(symbol['type'])
        sections[symbol['type']]
      elsif owner
        subsections[owner] ||= SUBSECTION_TYPES.keys.to_h { |type| [type, []] }
        subsections[owner][symbol['type']]
      end
    end

    def leaf_for(symbol, directory, namespace)
      {
        'name'        => symbol['name'],
        'tag'         => tag_for(symbol),
        'search_name' => search_name_for(symbol, namespace),
        'uri'         => "#{file_uri(directory)}/#{link_for(symbol)}",
      }
    end

    # Hangs each type's members off that type's own node, so expanding a class
    # in the sidebar reveals its constructors, methods, properties and signals.
    def attach_subsections(subsections, sections)
      REQUIRED.each do |type|
        sections.fetch(type, []).each do |item|
          item['children'] = subsection_nodes(subsections[item['name']], item['uri'])
        end
      end
    end

    def subsection_nodes(subsection, base_uri)
      if subsection.nil?
        []
      else
        subsection.filter_map do |type, members|
          if members.any?
            {
              'name'     => SUBSECTION_TYPES[type][0],
              'uri'      => "#{base_uri}#{SUBSECTION_TYPES[type][1]}",
              'children' => members,
            }
          end
        end
      end
    end

    def section_nodes(sections, index_uri)
      sections.filter_map do |type, members|
        if members.any?
          {
            'name'     => SECTION_TYPES[type][0],
            'uri'      => "#{index_uri}#{SECTION_TYPES[type][1]}",
            'children' => members,
          }
        end
      end
    end

    # Upstream sorts with String#localeCompare, which is case-insensitive at
    # the primary level; casecmp? first, then a case-sensitive tiebreak, gives
    # the same ordering for the ASCII identifiers gi-docgen emits.
    def sort_index(index)
      index.sort! { |a, b| compare_names(a['name'], b['name']) }
      index.each do |item|
        if item['children']
          sort_index(item['children'])
        end
      end
    end

    def compare_names(left, right)
      left.to_s.downcase.<=>(right.to_s.downcase).then do |by_fold|
        if by_fold.zero?
          left.to_s <=> right.to_s
        else
          by_fold
        end
      end
    end

    def file_uri(path) = "file://#{path}"

    # The page gi-docgen generates for each kind of symbol.
    def link_for(doc)
      case doc['type']
      when 'alias' then "alias.#{doc['name']}.html"
      when 'bitfield' then "flags.#{doc['name']}.html"
      when 'callback' then "callback.#{doc['name']}.html"
      when 'class' then "class.#{doc['name']}.html"
      when 'class_method' then "class_method.#{doc['struct_for']}.#{doc['name']}.html"
      when 'constant' then "const.#{doc['name']}.html"
      when 'content' then doc['href']
      when 'ctor' then "ctor.#{doc['type_name']}.#{doc['name']}.html"
      when 'domain' then "error.#{doc['name']}.html"
      when 'enum' then "enum.#{doc['name']}.html"
      when 'function', 'function_macro' then "func.#{doc['name']}.html"
      when 'interface' then "iface.#{doc['name']}.html"
      when 'method' then "method.#{doc['type_name']}.#{doc['name']}.html"
      when 'property' then "property.#{doc['type_name']}.#{doc['name']}.html"
      when 'record' then "struct.#{doc['name']}.html"
      when 'signal' then "signal.#{doc['type_name']}.#{doc['name']}.html"
      when 'type_func' then "type_func.#{doc['type_name']}.#{doc['name']}.html"
      when 'union' then "union.#{doc['name']}.html"
      when 'vfunc' then "vfunc.#{doc['type_name']}.#{doc['name']}.html"
      end
    end

    # The symbol kind shown as a pill beside each search result. Several
    # gi-docgen types are relabelled to the word a reader expects.
    def tag_for(doc)
      case doc['type']
      when 'method', 'class_method' then 'method'
      when 'content' then 'additional'
      when 'ctor' then 'constructor'
      when 'domain' then 'error'
      when 'function_macro' then 'macro'
      when 'record' then 'struct'
      when 'type_func' then 'function'
      else doc['type']
      end
    end

    # The fully qualified name the search view shows and fzy matches against:
    # the C type name for types, the C identifier for callables, and
    # "GtkWidget:name" / "GtkWidget::signal" / "GtkWidget.vfunc" for members
    # that only make sense qualified by their owner.
    def search_name_for(doc, namespace)
      case doc['type']
      when 'alias', 'bitfield', 'callback', 'class', 'domain', 'enum', 'interface', 'record'
        doc['ctype']
      when 'class_method', 'constant', 'ctor', 'function', 'function_macro', 'method', 'type_func'
        doc['ident']
      when 'property' then "#{namespace}#{doc['type_name']}:#{doc['name']}"
      when 'signal' then "#{namespace}#{doc['type_name']}::#{doc['name']}"
      when 'vfunc' then "#{namespace}#{doc['type_name']}.#{doc['name']}"
      when 'content' then doc['name']
      end
    end
end
