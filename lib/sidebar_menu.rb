# frozen_string_literal: true

require 'adwaita'

# SidebarMenu is the model behind the sidebar header bar's main menu button.
#
# Ported from the `menu menu_app` block at the bottom of upstream's
# src/sidebar/Sidebar.blp: four sections, in this order —
#
#   1. a custom item the theme selector is slotted into;
#   2. a custom item the zoom row is slotted into;
#   3. a "Bookmarks" submenu of eight online documentation sites, each opening
#      in a new tab;
#   4. Keyboard Shortcuts and About.
#
# The two custom items hold nothing themselves: they reserve a place in the
# popover that Sidebar fills with `popover.add_child(widget, id)`, which is
# how a GTK menu model carries a real widget.
class SidebarMenu
  THEME_SELECTOR_ID = 'themeswitcher'
  ZOOM_BUTTONS_ID = 'zoom_buttons'

  BOOKMARKS = {
    'Developer Documentation'    => 'https://developer.gnome.org/documentation/index.html',
    'Human Interface Guidelines' => 'https://developer.gnome.org/hig/',
    'JavaScript'                 => 'https://gjs.guide',
    'Vala'                       => 'https://valadoc.org/',
    'Rust'                       => 'https://gtk-rs.org',
    'Python'                     => 'https://pygobject.readthedocs.io/',
    'Blueprint'                  => 'https://gnome.pages.gitlab.gnome.org/blueprint-compiler/',
    'DevDocs'                    => 'https://devdocs.io/',
  }.freeze

  ABOUT_SECTION = {
    'Keyboard Shortcuts' => 'app.shortcuts',
    'About Biblioteca'   => 'app.about',
  }.freeze

  def model
    @model ||= Gio::Menu.new.tap do |menu|
      menu.append_section(nil, custom_section(THEME_SELECTOR_ID))
      menu.append_section(nil, custom_section(ZOOM_BUTTONS_ID))
      menu.append_section(nil, bookmarks_section)
      menu.append_section(nil, about_section)
    end
  end

  private

    # A section holding one item with nothing but a `custom` attribute, which
    # is what Gtk::PopoverMenu matches against the id passed to add_child.
    def custom_section(id)
      Gio::Menu.new.tap do |section|
        section.append_item(Gio::MenuItem.new(nil, nil).tap { |item| item['custom'] = id })
      end
    end

    def bookmarks_section
      Gio::Menu.new.tap do |section|
        section.append_submenu('Bookmarks', bookmarks_submenu)
      end
    end

    def bookmarks_submenu
      Gio::Menu.new.tap do |submenu|
        BOOKMARKS.each do |label, uri|
          # The detailed-action spelling carries the target, so every bookmark
          # shares one action and needs no handler of its own.
          submenu.append(label, "win.new-tab('#{uri}')")
        end
      end
    end

    def about_section
      Gio::Menu.new.tap do |section|
        ABOUT_SECTION.each { |label, action| section.append(label, action) }
      end
    end
end
