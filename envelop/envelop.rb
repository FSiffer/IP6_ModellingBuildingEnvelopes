require 'sketchup.rb'
require 'extensions.rb'

module Envelop

  # Utility method to mute Ruby warnings for whatever is executed by the block.
  def self.mute_warnings(&block)
    old_verbose = $VERBOSE
    $VERBOSE = nil
    result = block.call
  ensure
    $VERBOSE = old_verbose
    result
  end

  def self.reload(clear_model=false, show_dialogs=true)
    if clear_model
      Sketchup.active_model.entities.clear!
    end

    Envelop::ObserverUtils.detach_all_observers

    pattern = File.join(__dir__, '**', '*.rb')
    files = Dir.glob(pattern)
    self.mute_warnings do
      files.each { |filename|
        load(filename)
      }
    end
    puts "Reloaded #{files.size} files"

    # reset view/model state
    Sketchup.active_model.selection.clear
    Sketchup.active_model.active_view.lock_inference

    if show_dialogs
      Envelop::Main.show_dialogs
    end
  end

  def self.create_extension
    ex = SketchupExtension.new('Envelop', 'src/main')
    ex.description = 'Envelop: Quickly Modelling Building Envelops Based on PDF Plans'
    ex.version     = '0.1'
    # ex.copyright   = '' # TODO ?
    ex.creator     = 'Florian Siffer & Ptatrick Ackermann'

    Sketchup.register_extension(ex, true)

    ex
  end

  unless file_loaded?(__FILE__)
    @extension = create_extension
    @extension.check
    file_loaded(__FILE__)
  end

  Envelop::Main.show_dialogs
end # Envelop
