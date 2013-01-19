require_relative 'semaphore'

module MultiProcessing
  module Shared
    class ConditionVariable

      def initialize name=nil
        if !name
          @waiting = Semaphore.new 0
          @signal = Semaphore.new 0
        else
          @waiting = Semaphore.new name+"_waiting", Fcntl::O_CREAT, File::Stat::S_IRUSR|File::Stat::S_IWUSR, 0
          @signal = Semaphore.new name+"_waiting", Fcntl::O_CREAT, File::Stat::S_IRUSR|File::Stat::S_IWUSR, 0
        end
      end

      def signal
        begin
          @waiting.trywait
          @signal.post
          return true
        rescue => e
          return nil
        end
      end

      def broadcast
        while(signal)
        end
      end

      def wait mutex
        @waiting.post
        mutex.unlock
        @signal.wait
        mutex.lock
        self
      end

      def close
        @waiting.close
        @signal.close
      end

      def unlink
        @waiting.unlink
        @signal.unlink
      end

    end
  end
end

if __FILE__ == $0

  require_relative 'mutex'

  m = MultiProcessing::Shared::Mutex.new
  cond = MultiProcessing::Shared::ConditionVariable.new
  fork do
    m.synchronize do
      sleep 1
      puts "waiting p1"
      cond.wait(m)
      puts "restarted p1"
      sleep 1
      puts "end p1"
    end 
  end 
  fork do
    m.synchronize do
      sleep 1
      puts "waiting p2"
      cond.wait(m)
      puts "restarted p2"
      sleep 1
      puts "end p2"
    end 
  end 
  fork do
    m.synchronize do
      sleep 1
      puts "waiting p3"
      cond.wait(m)
      puts "restarted p3"
      sleep 1
      puts "end p3"
    end 
  end 
  sleep 5
  puts "cond signaling"
  cond.signal
  sleep 3
  puts "cond broadcasting"
  cond.broadcast
  Process.waitall
end
