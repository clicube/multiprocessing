require 'thread'

module MultiProcessing

	class ProcessError < StandardError; end

	class Mutex

		def initialize
			@pout,@pin = IO.pipe
      @pin.syswrite 1
			#@pin.write 1
      #@pin.flush
		end

		def lock
			unless @locking_pid == Process.pid && @locking_thread == Thread.current
				@pout.readpartial 1
				@locking_pid = Process.pid
				@locking_thread = Thread.current
			else
				raise ProcessError.new "mutex was tried locking twice"
			end
			self
		end

		def locked?
			begin
				@pout.read_nonblock 1
        @pin.syswrite 1
				#@pin.write 1
        #@pin.flush
				return false
			rescue Errno::EAGAIN => e
				return true
			end
		end

		def try_lock
			begin
				@pout.read_nonblock 1
				@locking_pid = Process.pid
				return true
			rescue Errno::EAGAIN
				return false
			end
		end

		def unlock
			return nil if !locked?
			if @locking_pid == Process.pid && @locking_thread == Thread.current
        @pin.syswrite 1
				#@pin.write 1
        #@pin.flush
				@locking_pid = nil
        @locking_thread = nil
				return self
			else
				raise ProcessError.new("mutex was tried unlocking in process/thread which didn't lock this mutex #{@locking_pid} #{Process.pid}")
			end
		end

		def synchronize
			begin
				lock
				ret = yield
			ensure
				unlock
			end
			return ret
		end

		def sleep(timeout=nil)
			sleep timeout
			unlock
		end
	end
end

if __FILE__ == $0

	puts "use lock and unlock"
	m = MultiProcessing::Mutex.new
	puts "locking mutex in main process(pid:#{Process.pid})"
	m.lock
	puts "locked mutex in main process(pid:#{Process.pid})"
	pid1 = fork do
		puts "locking mutex in child process(pid:#{Process.pid})"
		m.lock
		puts "locked mutex in child process(pid:#{Process.pid})"
		sleep 1
		puts "unlocking mutex in child process(pid:#{Process.pid})"
		m.unlock
		puts "unlocked mutex in child process(pid:#{Process.pid})"
		exit
	end
	pid2 = fork do
		puts "locking mutex in child process(pid:#{Process.pid})"
		m.lock
		puts "locked mutex in child process(pid:#{Process.pid})"
		sleep 1
		puts "unlocking mutex in child process(pid:#{Process.pid})"
		m.unlock
		puts "unlocked mutex in child process(pid:#{Process.pid})"
		exit
	end

	sleep 1
	puts "unlocking mutex in main process(pid:#{Process.pid})"
	m.unlock
	puts "unlocked mutex in main process(pid:#{Process.pid})"
	Process.waitall


	puts ""
	puts "use synchrnize"
	m = MultiProcessing::Mutex.new
	if pid = fork
		puts "synchronizing in main process(pid:#{Process.pid})"
		m.synchronize do
			puts "something to do in main process(pid:#{Process.pid})"
			sleep 2
			puts "end something in main process(pid:#{Process.pid})"
		end
		Process.waitpid pid
	else
		sleep 1
		puts "synchronizing in child process(pid:#{Process.pid})"
		m.synchronize do
			puts "something to do in child process(pid:#{Process.pid})"
			sleep 1
			puts "end something in child process(pid:#{Process.pid})"
		end
	end
end

