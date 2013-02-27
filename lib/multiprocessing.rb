require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/mutex')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/conditionvariable')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/semaphore')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/queue')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/namedpipe')
require File.expand_path(File.dirname(__FILE__) + '/multiprocessing/externalobject')

module MultiProcessing

  def try_handle_interrupt *args
    if Thread.respond_to?(:handle_interrupt)
      Thread.handle_interrupt(*args){ yield }
    else
      yield
    end
  end
  module_function :try_handle_interrupt

end

