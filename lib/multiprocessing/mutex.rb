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
  #   require 'multiprocessing'
  #   
  #   mutex = MultiProcessing::Mutex.new
  #   3.times do
  #     fork do
  #       mutex.synchronize do
  #         # critical section
  #         puts Process.pid
  #         sleep 1
  #       end
  #     end
  #   end
  #   Process.waitall
  #   # => prints 3 pids of forked process in 1 sec interval
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
    # @return [Mutex] self
    # @raise [ProcessError]
    #
    def lock
      MultiProcessing.try_handle_interrupt(RuntimeError => :on_blocking) do
        raise ProcessError.new "mutex was tried locking twice" if owned?
        @pout.readpartial 1
        @locking_pid = Process.pid
        @locking_thread = Thread.current
        self
      end
    end

    ##
    #
    # Returns true if this lock is currently held by some thread.
    #
    # @return [Boolean]
    #
    def locked?
      MultiProcessing.try_handle_interrupt(RuntimeError => :never) do
        begin
          @pout.read_nonblock 1
          @pin.syswrite 1
          false
        rescue Errno::EAGAIN
          true
        end
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
      MultiProcessing.try_handle_interrupt(RuntimeError => :never) do
        begin
          @pout.read_nonblock 1
          @locking_thread = Thread.current
          @locking_pid = Process.pid
          return true
        rescue Errno::EAGAIN
          return false
        end
      end
    end

    ##
    #
    # Returns true if the lock is locked by current thread on current process
    #
    # @return [Boolean]
    #
    def owned?
      @locking_pid == Process.pid && @locking_thread == Thread.current
    end

    ##
    #
    # Releases the lock.
    # Raises ProcessError if mutex wasn't locked by the current thread.
    #
    # @note An order of restarting thread is indefinite.
    #
    # @return [Mutex] self
    # @raise [ProcessError]
    #
    def unlock
      MultiProcessing.try_handle_interrupt(RuntimeError => :never) do
        raise ProcessError.new("Attempt to unlock a mutex which is not locked") unless locked?
        raise ProcessError.new("Mutex was tried being unlocked in process/thread which didn't lock this mutex: locking[pid:#{(@locking_pid||'nil')}, thread:#{@locking_thread.inspect}] current[pid:#{Process.pid}, thread:#{Thread.current.inspect}]") unless owned?
        @locking_pid = nil
        @locking_thread = nil
        @pin.syswrite 1
        self
      end
    end

    ##
    #
    # Obtains a lock, runs the block, and releases the lock when the block completes.
    #
    # @return [Object] returned value of block
    #
    def synchronize
      MultiProcessing.try_handle_interrupt(RuntimeError => :on_blocking) do
        lock
        ret = nil
        begin
          MultiProcessing.try_handle_interrupt(RuntimeError => :immediate) do
            ret = yield
          end
        ensure
          unlock
        end
        ret
      end
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
      MultiProcessing.try_handle_interrupt(RuntimeError => :on_blocking) do
        unlock
        begin
          timeout ? Kernel.sleep(timeout) : Kernel.sleep
        ensure
          lock
        end
      end
    end

  end
end

