require "./objects/main_process"

kind = ARGV[0] || :hma

MainProcess.call!
