require File.dirname(__FILE__) + "/log"
require "selenium-webdriver"
require "pry"
require "csv"

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
            Log.info "------------------------------------------------------------"
            craw_for_a_category home_headlink, index, driver
        end

        craw_for_a_category home_headlinks.first, 0, driver

        sleep 10

        driver.quit
        Log.info "End MainProcess#call!"
    end

    def craw_for_a_category home_headlink, index, driver
        baseconnect_companies_list = []
        result = []
        max_page = 200

        start_page = 1

        (start_page..max_page).each do |page|
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

            baseconnect_companies_list.each do |company|
                result << craw_a_company(company, index, page, driver, home_headlink)
            end
            #result << craw_a_company(baseconnect_companies_list.first, 0, page, driver, home_headlink)
          
            Log.info "#{index + 1}:\t#{page}:\tCrawed companies count: #{baseconnect_companies_list.size}"

            write_to_spread_sheet home_headlink, result, index, page

            File.open("./tmp/last_crawed_infor.txt", "w") do |file|
                file.write("Category: #{home_headlink[:name]}\nCategoryLink: #{home_headlink[:link]}\nPage: #{page}")
            end

            baseconnect_companies_list.clear
            result.clear
        end
    end

    def craw_a_company company, index, page, driver, home_headlink
        Log.info "#{index + 1}:\t#{page}:\tCraw #{company[:name]}"
        Log.info "#{index + 1}:\t#{page}:\t\t□ Access to #{company[:detail_link]}"
        driver.get(company[:detail_link])

        other_sites = driver.find_elements(:css, ".node__box__heading__link.node__box__heading__link-othersite a")
        basic_infors = driver.find_elements(:css, ".node__box.node__basicinfo .nodeTable--simple.nodeTable--simple__twoColumn.nodeTable--simple__twoColumn_side.cf dl")
        address_info = get_address_info driver
        {
            category_name: home_headlink[:name],
            name: driver.find_elements(:css, ".node__header__text__title").first&.attribute("innerHTML").to_s,
            home_page: other_sites[0]&.attribute("href"),
            contact_page: other_sites[1]&.attribute("href"),
            established_date: get_basic_info(basic_infors, :established_date),
            capital_stock: get_basic_info(basic_infors, :capital_stock),
            emp_num: get_basic_info(basic_infors, :emp_num).to_i,
            listed_market: get_basic_info(basic_infors, :listed_market),
            postcode: address_info[:postcode].to_s,
            province: address_info[:province].to_s,
            address: address_info[:address].to_s
        }
    end

    def get_address_info driver
        element = driver.find_elements(:css, ".nodeTable--simple.nodeTable--simple__oneColumn.cf dl dd p").first
        return {} if element.nil?

        addr_info = element.attribute("innerHTML").split("<br>")
        address = addr_info[1].strip!
        {
            postcode: addr_info[0].strip!,
            address: address,
            province: address.split(/都|県/)[0]
        }
    end

    def get_basic_info basic_infors, info_name
        mapping_info = {
            established_date: "設立年月",
            capital_stock: "資本金",
            emp_num: "従業員数",
            listed_market: "上場市場"
        }

        element = basic_infors.detect do |info|
            mapping_info[info_name] == info.find_elements(:css, "dt").first&.attribute("innerHTML")
        end

        return "" if element.nil?

        return element.find_elements(:css, "dd").first&.attribute("innerHTML").to_s
    end

    def get_all_home_headlinks driver
        Log.info "Get all home_headlinks"

        # elements = driver.find_elements(:css, ".home__headlink")
        # elements.map do |element|
        #    {
        #        name: element.find_element(:css, "h3").attribute("innerHTML"),
        #        link: element.attribute("href")
        #    }
        [
            {
                name: "大阪",
                link: "https://baseconnect.in/companies/prefecture/d80b180e-5fd9-4082-8cdc-a510179a3475/category/377d61f9-f6d3-4474-a6aa-4f14e3fd9b17"
            }
        ]
    end

    def write_to_spread_sheet home_headlink, result, index, page
        Log.info "#{index + 1}:\t#{page}:\tWrite to spread sheet"

        CSV.open("ITCompany#{Time.now.strftime("%Y%m%d")}.csv", "a+") do |csv|
          result.each do |company|
            csv << company.values
          end
        end
    end
  end
end
