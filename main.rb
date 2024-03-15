# require "./objects/main_process"
require "./objects/main_process_v2"

kind = ARGV[0] || :hma

MainProcess.call!
