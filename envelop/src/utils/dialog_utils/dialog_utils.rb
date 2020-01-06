module Envelop
    module DialogUtils
      # Public
      def self.execute_script(dialog_options, execute_script_parameter)
        if @dialogs[dialog_options[:id]].nil?
          warn "Envelop::DialogUtils.execute_script: could not find dialog with ID #{dialog_options[:id]}."
        else
          @dialogs[dialog_options[:id]].execute_script(execute_script_parameter)
        end
      end

      def self.show_dialog(dialog_options, &attach_callbacks_callback)
        if @dialogs[dialog_options[:id]]&.visible?
          @dialogs[dialog_options[:id]].bring_to_front
        else
          @dialogs[dialog_options[:id]]||= create_dialog(dialog_options)
          attach_callbacks_callback.call(@dialogs[dialog_options[:id]])

          @dialogs[dialog_options[:id]].show
        end
      end

      # Private
      def self.create_dialog(path_to_html:, title:, id:, height:, width:, pos_x:, pos_y:)
        options = {
          dialog_title: title,
          preferences_key: id,
          min_height: height, # TODO: consider making this window resizeable. TODO: ensure these settings actually work
          max_height: height,
          min_width: width,
          max_width: width,
          style: UI::HtmlDialog::STYLE_UTILITY
        }
        dialog = UI::HtmlDialog.new(options)
        dialog.set_file(path_to_html)
        dialog.set_can_close do
          false # TODO: this straight up does not work on Mac (Works on Windows)
        end

        dialog.set_size(width, height) # TODO: update this as the main window is resized.
        dialog.set_position(pos_x, pos_y) # TODO: update this as the main window is resized. # TODO: ensure window cannot be repositioned, but it needs to be able to be managed/hidden in some way

        dialog
      end

      def self.reload
        puts "dialog utils reload"
        if @dialogs
          @dialogs.each_value do |dialog|
            if dialog
              dialog.close
            end
          end
          remove_instance_variable(:@dialogs)
        end

        @dialogs = {}
      end
      reload
    end
end
