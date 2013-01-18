require_relative 'semaphore.so'

if $0 == __FILE__
  fork
  s = MultiProcessing::Semaphore.new("/testsemaphore",1)
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
