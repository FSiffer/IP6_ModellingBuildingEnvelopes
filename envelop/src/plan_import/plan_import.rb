require 'tempfile'
require_relative '../vendor/rb/image_size'

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
    HTML_HEIGHT = 150 + Envelop::WindowUtils.HTMLWindowHeaderAndVertScrollbarHeight

    #  Methods
    def self.create_dialog
      puts('Envelop::PlanImport.create_dialog()...')

      html_file = File.join(__dir__, 'plan_import.html')
      options = {
        dialog_title: 'Plan Import',
        preferences_key: 'envelop.planimport',
        min_height: Envelop::PlanImport::HTML_HEIGHT, # TODO: consider making this window resizeable
        max_height: Envelop::PlanImport::HTML_HEIGHT,
        min_width: Envelop::WindowUtils.ViewWidthPixels,
        max_width: Envelop::WindowUtils.ViewWidthPixels,
        style: UI::HtmlDialog::STYLE_UTILITY
      }
      dialog = UI::HtmlDialog.new(options)
      dialog.set_file(html_file)
      dialog.set_can_close do
        false # TODO: this straight up does not work on Mac (Works on Windows)
      end

      dialog.set_size(Envelop::WindowUtils.ViewWidthPixels, Envelop::PlanImport::HTML_HEIGHT) # TODO: update this as the main window is resized.
      dialog.set_position(0, Envelop::WindowUtils.ViewHeightPixels - Envelop::PlanImport::HTML_HEIGHT + Envelop::WindowUtils.SketchupMenuAndToolbarHeight) # TODO: ensure window cannot be repositioned, but it needs to be able to be managed/hidden in some way
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
