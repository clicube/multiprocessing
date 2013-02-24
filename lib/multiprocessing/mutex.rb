require 'thread'
require File.expand_path(File.dirname(__FILE__) + '/processerror')

module MultiProcessing

  ##
  #
  # Process version of Mutex.
  # This can be used like ::Mutex in Ruby standard library.
  #
  # Do not fork in #synchronize block or before #unlock.
  # Forking and forked process run in parallel.
  #
  # Note that Mutex uses 1 pipe.
  #
  # @example
  #   mutex = MultiProcessing::Mutex.new
  #   fork
  #   mutex.synchronize do
  #     # critical section
  #     puts Process.pid
  #     sleep 1
  #   end
  # 
  class Mutex

    def initialize
      @pout,@pin = IO.pipe
      @pin.syswrite 1
    end

    ##
    #
    # Attempts to grab the lock and waits if it isn't available.
    # Raises ProcessError if mutex was locked by the current thread.
    #
    # @return [Mutex] itself
    # @raise [ProcessError]
    #
    def lock
      unless @locking_pid == ::Process.pid && @locking_thread == Thread.current
        @pout.readpartial 1
        @locking_pid = ::Process.pid
        @locking_thread = Thread.current
      else
        raise ProcessError.new "mutex was tried locking twice"
      end
      self
    end

    ##
    #
    # Returns true if this lock is currently held by some thread.
    #
    # @return [Boolean]
    #
    def locked?
      begin
        @pout.read_nonblock 1
        @pin.syswrite 1
        return false
      rescue Errno::EAGAIN => e
        return true
      end
    end

    ##
    #
    # Attempts to obtain the lock and returns immediately.
    # Returns true if the lock was granted.
    #
    # @return [Boolean]
    #
    def try_lock
      begin
        @pout.read_nonblock 1
        @locking_thread = Thread.current
        @locking_pid = ::Process.pid
        return true
      rescue Errno::EAGAIN
        return false
      end
    end

    ##
    #
    # Releases the lock.
    # Raises ProcessError if mutex wasn't locked by the current thread.
    #
    # @return [Mutex] itself
    # @raise [ProcessError]
    #
    def unlock
      raise ProcessError.new("Attempt to unlock a mutex which is not locked") if !locked?
      if @locking_pid == ::Process.pid && @locking_thread == Thread.current
        @pin.syswrite 1
        @locking_pid = nil
        @locking_thread = nil
        return self
      else
        raise ProcessError.new("mutex was tried unlocking in process/thread which didn't lock this mutex #{@locking_pid} #{::Process.pid}")
      end
    end

    ##
    #
    # Obtains a lock, runs the block, and releases the lock when the block completes.
    #
    # @return [Object] returned value of block
    #
    def synchronize
      lock
      begin
        ret = yield
      ensure
        unlock if locked?
      end
      return ret
    end

    ##
    #
    # Releases the lock and sleeps timeout seconds if it is given and non-nil or forever.
    # Raises ProcessError if mutex wasn't locked by the current thread.
    #
    # @param [Numeric,nil] timeout
    # @raise [ProcessError]
    #
    def sleep timeout=nil
      unlock
      timeout ? Kernel.sleep(timeout) : Kernel.sleep
      lock
    end
  end
end

