require File.dirname(__FILE__) + "/objects/log"
require "selenium-webdriver"
require "pry"
require "csv"

class TestIp
  class << self
    def init_selenium_driver
        Log.info "Init driver"

        tor_proxy = "127.0.0.1:9150"
        options = Selenium::WebDriver::Chrome::Options.new(
          args: [
            '--test-type',
            '--ignore-certificate-errors',
            "--disable-extensions",
            "disable-infobars",
            "--incognito",
            "--proxy-server=socks5://#{tor_proxy}"
        ])

        Selenium::WebDriver.logger.output = File.join("./tmp", "selenium.log")
        Selenium::WebDriver.logger.level = :warn
        Selenium::WebDriver.for :chrome, options: options
    end

    def call!
        system "start firefox"
        sleep 10

        driver = init_selenium_driver

        driver.get "http://ipinfo.io"

        sleep 10

        driver.quit
        system "taskkill /F /IM firefox.exe"
    end
  end
end

TestIp.call!
