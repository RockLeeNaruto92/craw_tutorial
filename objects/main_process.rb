require File.dirname(__FILE__) + "/log"
require File.dirname(__FILE__) + "/information"
require "selenium-webdriver"
require "pry"

class MainProcess
  class << self
    def init_selenium_driver
        Log.info "Init driver"
        Selenium::WebDriver.logger.output = File.join("./tmp", "selenium.log")
        Selenium::WebDriver.logger.level = :warn
        Selenium::WebDriver.for :chrome
    end

    def call!
        baseconnect_home_page = "https://baseconnect.in"

        Log.info "Start to craw data"

        driver = init_selenium_driver

        Log.info "Access to baseconnect.in"
        driver.get baseconnect_home_page

        home_headlinks = get_all_home_headlinks driver

        home_headlinks.each_with_index do |home_headlink, index|
            # TODO
            Log.info "------------------------------------------------------------"
            craw_for_a_category home_headlink, index
        end

        driver.quit
        Log.info "End MainProcess#call!"
    end

    def craw_for_a_category home_headlink, index
        baseconnect_companies_list = []
        result = []
        max_page = 2

        (1..max_page).each do |page|
            category_index_link = home_headlink[:link] + (page == 1 ? "" : "?page=#{page}")
            Log.info "#{index + 1}:\t#{page}\tAccess to #{category_index_link}"
            Log.info "\t\tRetrieve companies link"

            baseconnect_companies_list = [
                {
                    name: "イオンリテール株式会社",
                    detail_link: "https://baseconnect.in" + "/companies/0bfa81ce-0bc2-4e1f-b6e7-46d9596e3d10"
                }
            ]

            baseconnect_companies_list.each do |company|
                result << craw_a_company(company, index, page)
            end
          
            Log.info "#{index + 1}:\t#{page}:\tCrawed companies count: #{baseconnect_companies_list.size}"

            write_to_spread_sheet home_headlink, result, index, page

            baseconnect_companies_list.clear
            result.clear
        end
    end

    def craw_a_company company, index, page
        Log.info "#{index + 1}:\t#{page}:\tCraw #{company[:name]}"

        # TODO
        {
            name: "日立建機株式会社",
            home_page: "https://www.hitachicm.com/global/jp/",
            contact_page: "https://www.hitachicm.com/global/jp/contact-us/",
            established_date: "1970/10",
            capital_stock: "815億7659万円",
            emp_num: "5527",
            listed_market: "東証１部",
            postcode: "110-0015",
            province: "東京",
            address: "東京都台東区東上野２丁目１６番１号"
        }
    end

    def get_all_home_headlinks driver
        Log.info "Get all home_headlinks"

        elements = driver.find_elements(:css, ".home__headlink")
        elements.map do |element|
            name = 
            {
                name: element.find_element(:css, "h3").attribute("innerHTML"),
                link: element.attribute("href")
            }
        end
    end

    def write_to_spread_sheet home_headlink, result, index, page
        # TODO
        Log.info "#{index + 1}:\t#{page}:\tWrite to spread sheet"
    end
  end
end
