# require "google_drive"
require "fileutils"
require File.dirname(__FILE__) + "/log"
require File.dirname(__FILE__) + "/constants/information_constant"

class Information
  extend InformationConstant

  # Config to load spreadsheet
  #cert_path = Gem.loaded_specs["google-api-client"].full_gem_path+"/lib/cacerts.pem"
  #ENV["SSL_CERT_FILE"] = cert_path

  # Worksheet variables
  @@links_worksheet = nil
  @@machines_list_worksheet = nil
  @@anti_captcha_worksheet = nil
  @@vpn_accounts_worksheet = nil

  @@kind = :hma
  # [:hma, :ip_vanish]

  class << self
    def generate_link_txt_files
      Log.info "Information#generate_link_txt_files"

      create_links_folder

      (1..links_worksheet.num_cols).each do |col|
        generate_link_txt_file links_worksheet[1, col], col
      end
    end

    private

    def key
      case @@kind
      when :ip_vanish
        IP_VANISH_SPREAD_SHEET_KEY
      when :vidoza_ip_vanish
        VIDOZA_IP_VANISH_SPREAD_SHEET_KEY
      when :openload_ip_vanish
        OPENLOAD_IP_VANISH_SPREAD_SHEET_KEY
      when :openload_express_vpn
        OPENLOAD_EXPRESS_VPN_SPREAD_SHEET_KEY
      when :openload_pure_vpn
        OPENLOAD_PURE_VPN_SPREAD_SHEET_KEY
      when :openload_hma
        OPENLOAD_HMA_SPREAD_SHEET_KEY
      else
        HMA_SPREAD_SHEET_KEY
      end
    end

    def config_json_path
      CONFIG_JSON_PATH
    end

    def links_worksheet
      @@links_worksheet = worksheet :links, @@links_worksheet
    end

    def machines_list_worksheet
      @@machines_list_worksheet = worksheet :machines_list, @@machines_list_worksheet
    end

    def anti_captcha_worksheet
      @@anti_captcha_worksheet = worksheet :anti_captcha, @@anti_captcha_worksheet
    end

    def vpn_accounts_worksheet
      @@vpn_accounts_worksheet = worksheet :vpn_accounts, @@vpn_accounts_worksheet
    end

    def worksheet name, sheet_variable
      return sheet_variable if sheet_variable
      sheet_info = WORKSHEETS[name.to_sym]
      initialize_worksheet sheet_info[:id], key, config_json_path
    end

    def initialize_session config_json_path
      GoogleDrive::Session.from_config(config_json_path)
    end

    def initialize_speadsheet_session key, config_json_path
      @@session ||= initialize_session config_json_path
      @@session.spreadsheet_by_key(key)
    end

    def initialize_worksheet worksheet_id, key, config_json_path
      @@spreadsheet ||= initialize_speadsheet_session key, config_json_path
      @@spreadsheet.worksheets[worksheet_id]
    end
  end
end
