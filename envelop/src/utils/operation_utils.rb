# frozen_string_literal: true

module Envelop
  module OperationUtils

    @is_operation_active = false
    
    #
    # start an operation and execute the implicit block, if it returns true 
    # the operation is committed otherwise it is aborted
    #
    # @param name [String] the name of the operation
    # @param transparent [Boolean] if set to true, this operation will append to the previous operation
    #
    # @yieldreturn [Boolean] whether the operation was successful and should get commited
    #
    # @return [Boolean] true if the operation was commited, false otherwise
    #
    def self.operation_block(name, transparent: false)
      Sketchup.active_model.start_operation(name, true, false, transparent)
      puts "Envelop::OperationUtils.operation_block start_operation \"#{name}\"" unless transparent
      if yield
        puts "Envelop::OperationUtils.operation_block commit_operation \"#{name}\"" unless transparent
        Sketchup.active_model.commit_operation
        true
      else
        puts "Envelop::OperationUtils.operation_block abort_operation \"#{name}\"" unless transparent
        Sketchup.active_model.abort_operation
        false
      end
    end
    
    #
    # start an operation and then execute a list of lambdas.
    # if a lambda returns false the operation is aborted and the following lambdas are not executed
    #
    # @return [Boolean] true if the operation was commited, false otherwise
    # 
    # @example
    #   Envelop::OperationUtils.operation_chain "Operation", lambda  {
    #     puts "First part"
    #     true
    #   }, lambda  {
    #     puts "Second part"
    #     true
    #   }
    #
    def self.operation_chain(name, *lambdas)
      Sketchup.active_model.start_operation(name, true)
      puts "Envelop::OperationUtils.operation_chain start_operation \"#{name}\""
      
      lambdas.each do | lambda |
        next if lambda.call

        puts "Envelop::OperationUtils.operation_chain abort_operation \"#{name}\""
        Sketchup.active_model.abort_operation
        return false
      end
      
      puts "Envelop::OperationUtils.operation_chain commit_operation \"#{name}\""
      Sketchup.active_model.commit_operation
      true
    end

    def self.start_operation(name)
      if not @is_operation_active
        @is_operation_active = true
        Sketchup.active_model.start_operation(name, true)
        return true
      else
        warn 'Envelop::OperationUtils.start_operation: start_operation called but there is already an operation active'
        return false
      end
    end

    def self.commit_operation()
      if @is_operation_active
        @is_operation_active = false
        Sketchup.active_model.commit_operation
        return true
      else
        warn 'Envelop::OperationUtils.commit_operation: commit_operation called but there is no operation active to commit'
        return false
      end
    end

    def self.abort_operation
      if @is_operation_active
        @is_operation_active = false
        Sketchup.active_model.abort_operation
        return true
      else
        warn 'Envelop::OperationUtils.abort_operation: abort_operation called but there is no operation active to abort'
        return false
      end
    end

  end
end
