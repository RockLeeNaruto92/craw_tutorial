require File.dirname(__FILE__) + "/log"
require "selenium-webdriver"
require "pry"
require "csv"

class MainProcess
  class << self
    WORKING_AT_ICON = "https://static.xx.fbcdn.net/rsrc.php/v3/yy/r/2b4AYlZqdlw.png"
    STUDIED_AT_ICON = "https://static.xx.fbcdn.net/rsrc.php/v3/yU/r/_kTTuiBidlL.png"
    FROM_ICON = "https://static.xx.fbcdn.net/rsrc.php/v3/yr/r/aw-eU53JG-u.png"
    LIVES_AT_ICON = "https://static.xx.fbcdn.net/rsrc.php/v3/y4/r/HNzy6p26p_d.png"
    SEX_ICON = "https://static.xx.fbcdn.net/rsrc.php/v3/yj/r/qXTmWu_dlXK.png"
    BIRTH_DAY_ICON = "https://static.xx.fbcdn.net/rsrc.php/v3/yT/r/fzYWd7dALbn.png"

    def init_selenium_driver
        Log.info "Init driver"
        Selenium::WebDriver.logger.output = File.join("./tmp", "selenium.log")
        Selenium::WebDriver.logger.level = :warn
        Selenium::WebDriver.for :firefox
    end

    def call!
        @facebook_home_page = "https://www.facebook.com"
        @driver = init_selenium_driver

        login_facebook

        group_users_links = retrieve_group_users_link

        Log.info "Number of user link: #{group_users_links.length}"

        user_infos = []
        uinfo = nil

        group_users_links.each_with_index do |gul, index|
            uinfo = craw_user_data gul, index
            user_infos << uinfo unless uinfo.nil?
            uinfo = nil

            if user_infos.length == 50
                write_to_csv user_infos
                user_infos.clear
            end
        end

        write_to_csv user_infos

        @driver.quit

        Log.info "End MainProcess#call!"
    end

    def write_to_csv user_infos
        Log.info "Write to csv"

        CSV.open("user_infos.csv", "a+") do |csv|
          user_infos.each do |user_info|
            csv << user_info.values
          end
        end
    end

    def craw_user_data group_user_link, index
        user_data = {}

        @driver.get group_user_link
        Log.info "#{index}\t: Accessed to #{group_user_link}"

        sleep 5

        profile_link = @driver.find_elements(:css, "a[href*='https://www.facebook.com/profile.php?']")&.first

        if profile_link.nil?
            Log.warning "\t\tDo not existed link #{group_user_link}"
            return
        end

        profile_link.click
        Log.info "\t\tAccessed to profile page"
        sleep 3

        profile_page = @driver.current_url

        user_data[:profile_link] = profile_page

        # name
        h1_elements = @driver.find_elements(:css, "h1")
        h1_elements.each do |el|
            unless el.attribute("innerText").include?("Thông báo")
                user_data[:name] = el.attribute("innerText") 
            end
        end

        overview_page = if profile_page.include?("profile.php?id=")
            "#{profile_page}&sk=about_overview"
        else
            "#{profile_page}about_overview"
        end
        @driver.get overview_page
        Log.info "\t\t\tAccessed to overview page"
        sleep 3

        # Working place
        working_at_img = @driver.find_elements(:css, "img[src='#{WORKING_AT_ICON}']")&.first
        container = working_at_img&.find_elements(:xpath, "../..")&.first
        working_place_link = container&.find_elements(:css, "a")&.first
        user_data[:working_place] = working_place_link&.attribute("innerText")
        Log.info "\t\t\tWorking place: #{user_data[:working_place]}"

        # Studied school
        studied_at_img = @driver.find_elements(:css, "img[src='#{STUDIED_AT_ICON}']")&.first
        container = studied_at_img&.find_elements(:xpath, "../..")&.first
        studied_at_div = container&.find_elements(:css, "div > div")&.first
        user_data[:studied_school] = studied_at_div&.attribute("innerText")
        Log.info "\t\t\tStudied school: #{user_data[:studied_school]}"

        # Lives at
        lives_at_img = @driver.find_elements(:css, "img[src='#{LIVES_AT_ICON}']")&.first
        container = lives_at_img&.find_elements(:xpath, "../..")&.first
        lives_at_link = container&.find_elements(:css, "a")&.first
        user_data[:lives_at] = lives_at_link&.attribute("innerText")
        Log.info "\t\t\tLives at: #{user_data[:lives_at]}"

        # From
        from_img = @driver.find_elements(:css, "img[src='#{FROM_ICON}']")&.first
        container = from_img&.find_elements(:xpath, "../..")&.first
        lives_at_link = container&.find_elements(:css, "a")&.first
        user_data[:from] = lives_at_link&.attribute("innerText")
        Log.info "\t\t\tfrom: #{user_data[:from]}"

        sleep 1

        contact_and_basic_info_page = if profile_page.include?("profile.php?id=")
            "#{profile_page}&sk=about_contact_and_basic_info"
        else
            "#{profile_page}about_contact_and_basic_info"
        end
        @driver.get contact_and_basic_info_page
        Log.info "\t\t\tAccessed to contact and basic info page"

        sleep 3

        # Sex
        sex_img = @driver.find_elements(:css, "img[src='#{SEX_ICON}']")&.first
        container = sex_img&.find_elements(:xpath, "../..")&.first
        sex_span = container&.find_elements(:css, "div > div > div > div > div > div > span ")&.first
        user_data[:sex] = sex_span&.attribute("innerText")
        Log.info "\t\t\tSex: #{user_data[:sex]}"

        # Birthday
        birthday_img = @driver.find_elements(:css, "img[src='#{BIRTH_DAY_ICON}']")&.first
        container = birthday_img&.find_elements(:xpath, "../..")&.first
        birth_spans = container&.find_elements(:css, "div > div > div > div > div > div > span")
        
        if !birth_spans.nil?
            user_data[:birth_day] = birth_spans[0]&.attribute("innerText")
            user_data[:birth_year] = birth_spans[2]&.attribute("innerText")
        end
        Log.info "\t\t\tBirthday: #{user_data[:birth_day]}"
        Log.info "\t\t\tBirthyear: #{user_data[:birth_year]}"

        return user_data
    end
    
    def retrieve_group_users_link
        file = File.open("./group_users_link.csv", "r")
        data = file.readlines.map &:chomp
        file.close
        
        data.uniq!
        return data
    end

    def login_facebook
        @driver.get @facebook_home_page
        Log.info "Accessed to facebook home page"

        fb_account = get_fb_account_info

        email_field = @driver.find_elements(:css, "input#email").first
        email_field.send_keys fb_account[:username]
        Log.info "Inputed to username"

        sleep 2

        password_field = @driver.find_elements(:css, "input#pass").first
        password_field.send_keys fb_account[:password]
        Log.info "Inputed to password"

        sleep 2

        login_btn = @driver.find_elements(:css, "button[name='login']").first
        login_btn.click
        Log.info "Clicked Login button"

        sleep 10
    end

    def get_fb_account_info
       file = File.open("./configs/fb.txt", "r")
       account_data = file.readlines.map &:chomp
       file.close

       {
          username: account_data[0],
          password: account_data[1]
       }
    end
  end
end
