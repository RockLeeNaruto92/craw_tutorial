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
      baseconnect_home_page = "https://www.r-agent.com/kensaku/companylist/industry1-01/"

      Log.info "Start to craw data"

      driver = init_selenium_driver

      Log.info "Access to r-agent.com"

      driver.get baseconnect_home_page

      companies = get_all_companies driver
      companies.each_with_index do |company, index|
        Log.info "------------------------------------------------------------"
        write_to_spread_sheet craw_a_company(
                                company[:link],
                                company[:name],
                                company[:num_of_job],
                                company[:info],
                                company[:address],
                                index,
                                driver
                              )
      end

      sleep 10

      driver.quit

      Log.info "End MainProcess#call!"
    end

    def craw_a_company(link, name, num_of_job, info, address, index, driver)
      Log.info "#{index + 1}:\tCraw #{name}"
      Log.info "#{index + 1}:\t\t□ Access to #{link}"

      driver.get link

      see_more_info driver

      title = driver.find_elements(:xpath, '//meta[@property="og:title"]').first&.attribute('content').to_s
      description = driver.find_elements(:xpath, '//meta[@property="og:description"]').first&.attribute('content').to_s
      representative = driver.find_elements(:xpath, '(//main//table//td[@colspan="3"])[1]').first
      number_of_employees = driver.find_elements(:xpath, '(//main//table//td[@colspan="3"])[2]').first
      notes = driver.find_elements(:xpath, '(//main//table)[2]//td[@colspan="5"]/p').last

      {
        link: link,
        name: name,
        title: title,
        num_of_job: num_of_job,
        info: info,
        address: address,
        description: description,
        representative: representative.nil? ? "" : representative.text,
        number_of_employees: number_of_employees.nil? ? "" : number_of_employees.text.scan(/\d/).join(''),
        notes: notes.nil? ? "" : notes.text
      }
    end

    def see_more_info(driver)
      el_see_more = driver.find_elements(:xpath, '//main//div[contains(@class, "isClose")]').first
      el_see_more.click unless el_see_more.nil?
    end

    def get_all_companies(driver)
      Log.info "Get all companies"

      companies = []

      elements = driver.find_elements(:xpath, '//main//section//div[@class="a"][not(@style)]')
      elements.each do |element|
        el_link = element.find_element(:xpath, './a')
        el_name = element.find_elements(:xpath, './a/div/div')[0]
        el_num_of_job = element.find_elements(:xpath, './a/div/div')[1]
        el_info = element.find_elements(:xpath, './a//styled-company-info-desp').first
        el_address = element.find_elements(:xpath, './a//p').last

        companies.push({
                         link: el_link.nil? ? "" : el_link.attribute('href'),
                         name: el_name.nil? ? "" : el_name.text,
                         num_of_job: el_num_of_job.nil? ? "" : el_num_of_job.text.scan(/\d/).join(''),
                         info: el_info.nil? ? "" : el_info.text,
                         address: el_address.nil? ? "" : el_address.text,
                       })
      end

      companies
    end

    def write_to_spread_sheet(result)
      CSV.open("R_Agent_Company#{Time.now.strftime("%Y%m%d")}.csv", "a+") do |csv|
        csv << result.values
      end
    end
  end
end
