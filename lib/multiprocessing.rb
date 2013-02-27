require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/mutex')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/conditionvariable')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/semaphore')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/queue')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/namedpipe')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/externalobject')

module MultiProcessing

  ##
  #
  # If Thread has handle_interrupt (Ruby 2.0.0 or later), call it with given arguments and block.
  # If not, simply yield passed block
  #
  # @param [Array<Object>] args arguments to give Thread.handle_interrupt
  # @return [Object] returned value of the block
  #
  def try_handle_interrupt *args
    if Thread.respond_to?(:handle_interrupt)
      Thread.handle_interrupt(*args){ yield }
    else
      yield
    end
  end
  module_function :try_handle_interrupt

end

