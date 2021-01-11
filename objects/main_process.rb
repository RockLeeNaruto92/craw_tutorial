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

        #home_headlinks.each_with_index do |home_headlink, index|
        #    Log.info "------------------------------------------------------------"
        #    craw_for_a_category home_headlink, index, driver
        #end

        craw_for_a_category home_headlinks.first, 0, driver

        driver.quit
        Log.info "End MainProcess#call!"
    end

    def craw_for_a_category home_headlink, index, driver
        baseconnect_companies_list = []
        result = []
        max_page = 2

        (1..max_page).each do |page|
            category_index_link = home_headlink[:link] + (page == 1 ? "" : "?page=#{page}")
            Log.info "#{index + 1}:\t#{page}\tAccess to #{category_index_link}"
            driver.get category_index_link
            Log.info "\t\tRetrieve companies link"

            elements = driver.find_elements(:css, ".searches__result__list__header__title a")

            break if elements.empty?

            baseconnect_companies_list = elements.map do |element|
                {
                    name: element.attribute("innerHTML"),
                    detail_link: element.attribute("href")
                }
            end

            #baseconnect_companies_list.each do |company|
            #    result << craw_a_company(company, index, page, driver)
            #end
            result << craw_a_company(baseconnect_companies_list.first, 0, page, driver)
            binding.pry
          
            Log.info "#{index + 1}:\t#{page}:\tCrawed companies count: #{baseconnect_companies_list.size}"

            write_to_spread_sheet home_headlink, result, index, page

            baseconnect_companies_list.clear
            result.clear
        end
    end

    def craw_a_company company, index, page, driver
        Log.info "#{index + 1}:\t#{page}:\tCraw #{company[:name]}"
        Log.info "#{index + 1}:\t#{page}:\t\t□ Access to #{company[:detail_link]}"
        driver.get(company[:detail_link])

        other_sites = driver.find_elements(:css, ".node__box__heading__link.node__box__heading__link-othersite a")
        basic_infors = driver.find_elements(:css, ".node__box.node__basicinfo .nodeTable--simple.nodeTable--simple__twoColumn.nodeTable--simple__twoColumn_side.cf dl")
        
        {
            name: driver.find_elements(:css, ".node__header__text__title").first&.attribute("innerHTML").to_s,
            home_page: other_sites[0]&.attribute("href"),
            contact_page: other_sites[1]&.attribute("href"),
            established_date: get_basic_info(basic_infors, :established_date),
            capital_stock: get_basic_info(basic_infors, :capital_stock),
            emp_num: get_basic_info(basic_infors, :emp_num).to_i,
            listed_market: get_basic_info(basic_infors, :listed_market),
            postcode: "110-0015",
            province: "東京",
            address: "東京都台東区東上野２丁目１６番１号"
        }
    end

    def get_basic_info basic_infors, info_name
        mapping_info = {
            established_date: "設立年月",
            capital_stock: "資本金",
            emp_num: "従業員数",
            listed_market: "従業員数"
        }

        element = basic_infors.detect do |info|
            mapping_info[info_name] == info.find_elements(:css, "dt").first&.attribute("innerHTML")
        end

        return element.find_elements(:css, "dd").first&.attribute("innerHTML")
    end

    def get_all_home_headlinks driver
        Log.info "Get all home_headlinks"

        elements = driver.find_elements(:css, ".home__headlink")
        elements.map do |element|
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
