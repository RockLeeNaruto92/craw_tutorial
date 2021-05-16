require "colorize"

class Log
  TMP_FOLDER = File.dirname(__FILE__) + "/../tmp"
  LOG_TXT = "#{TMP_FOLDER}/log.txt"

  @@debug_mode = :both
  # :stdout
  # :file
  # :both

  class << self
    def debug_mode debug_mode = :both
      @@debug_mode = debug_mode
    end

    def info message
      case @@debug_mode
      when :stdout
        puts "[INFO]:\t\t#{message}".green
      when :file
        write_log_to_file "#{Time.now} [INFO]:\t\t#{message}"
      when :both
        puts "[INFO]:\t\t#{message}".green
        write_log_to_file "#{Time.now} [INFO]:\t\t#{message}"
      end
    end

    def error message
      case @@debug_mode
      when :stdout
        puts "[ERROR]:\t#{message}".red
      when :file
        write_log_to_file "#{Time.now} [ERROR]:\t#{message}"
      when :both
        puts "[ERROR]:\t#{message}".red
        write_log_to_file "#{Time.now} [ERROR]:\t#{message}"
      end
    end

    def warning message
      case @@debug_mode
      when :stdout
        puts "[WARN]:\t\t#{message}".yellow
      when :file
        write_log_to_file "#{Time.now} [WARN]:\t\t#{message}"
      when :both
        puts "[WARN]:\t\t#{message}".yellow
        write_log_to_file "#{Time.now} [WARN]:\t\t#{message}"
      end
    end

    def delete_log_file
      return unless File.exist? LOG_TXT

      File.delete LOG_TXT
      info "Deleted #{LOG_TXT}"
    end

    def write_log_to_file message
      File.open(LOG_TXT, "a"){|f| f.puts message}
    end
  end
end
