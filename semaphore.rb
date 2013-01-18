require 'fcntl'
require_relative 'semaphore.so'

module MultiProcessing
  class Semaphore
    def initialize *args
      if args.length == 1
        value = args[0]
        time = Time.now
        usec = time.tv_sec*1000000+time.tv_usec
        loop do
          begin
            name = "/" << usec.to_s
            open name, Fcntl::O_CREAT|Fcntl::O_EXCL, File::Stat::S_IRUSR|File::Stat::S_IWUSR, value
            break
          rescue Errno::EEXIST
            usec += 1
          end
        end
      else
        open *args
      end
    end

    def synchronize
      begin
        wait
        yield
      ensure
        post
      end
    end

    def self.open name, oflag, mode=nil, value=nil
      self.new name, oflag, mode, value
    end
  end
end

if $0 == __FILE__
  s = MultiProcessing::Semaphore.new(1)
  puts s.name
  fork
  s.wait
  puts Process.pid
  sleep 1
  s.post
  s.close
  begin
    s.unlink
  rescue
  end
end
