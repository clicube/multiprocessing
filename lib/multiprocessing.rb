require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/mutex')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/conditionvariable')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/semaphore')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/queue')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/namedpipe')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/externalobject')

##
#
# MultiProcessing provides classes for
# inter-process synchronization and communication in Ruby.
#
# These classes can be used like ones in Ruby standard library for multi threading.
#
# To realize communitation across processes, MultiProcessing uses pipe (IO.pipe).
# You have to use fork to create multiple processes 
# which accesses synchronizing/communication object.
# For this reason, MultiProcessing can be used only on Unix or Linux.
#
#
module MultiProcessing

  # documentation is at below
  if Thread.respond_to?(:handle_interrupt)
    def try_handle_interrupt *args, &block
      Thread.handle_interrupt(*args, &block)
    end
  else
    def try_handle_interrupt *args
      yield
    end
  end
  module_function :try_handle_interrupt
  ##
  #
  # @!method try_handle_interrupt *args
  # @scope class
  #
  # If Thread has handle_interrupt (Ruby 2.0.0 or later), call it with given arguments and block.
  # If not, simply yield passed block
  #
  # @param [Array<Object>] args arguments to give Thread.handle_interrupt
  # @return [Object] returned value of the block
  #
  ##

end

