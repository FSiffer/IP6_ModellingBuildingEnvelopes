require 'tempfile'
require_relative '../vendor/rb/image_size'
require_relative '../vendor/rb/os'

module Envelop
  module PlanImport
    # Public
    def self.show_dialog
      if @dialog&.visible?
        @dialog.bring_to_front
      else
        @dialog ||= create_dialog
        @dialog.add_action_callback('import_image') do |_action_context, string|
          Envelop::PlanEdit.open_dialog(string)
          nil
        end
        @dialog.show
      end
    end

    private

    # Settings
    HTML_HEIGHT = 150 + 26 #  TODO: verify this is correct on all platforms (+ 26 for size of title bar)

    #  Methods

    def self.create_dialog
      puts('Envelop::PlanImport.create_dialog()...')

      view = Sketchup.active_model.active_view
      html_height = Envelop::PlanImport::HTML_HEIGHT

      html_file = File.join(__dir__, 'plan_import.html')
      options = {
        dialog_title: 'Plan Import',
        preferences_key: 'envelop.planimport',
        min_height: html_height,
        max_height: html_height,
        style: UI::HtmlDialog::STYLE_UTILITY
      }
      dialog = UI::HtmlDialog.new(options)
      dialog.set_file(html_file)
      dialog.set_can_close do
        false # TODO: this straight up does not work on Mac (Works on Windows)
      end
      dialog.set_size(Envelop::WindowUtils.ViewWidthPixels, html_height) # TODO: update this as the window is resized & make not resizeable
      #dialog.center # TODO: position calculation wrong on windows

      y_pos = Envelop::WindowUtils.ViewHeightPixels - html_height
      if OS.mac? # this assumes sketchup is running windowed but that the window is at max size
          y_pos = y_pos + 88
      end

      dialog.set_position(0, y_pos) # TODO: make it so this cannot be changed?
      dialog
    end

    def self.reload
      if @dialog
        @dialog.close
        remove_instance_variable(:@dialog)
      end
    end
    reload
  end
end
