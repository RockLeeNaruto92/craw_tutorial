require File.dirname(__FILE__) + "/log"
require "selenium-webdriver"
require "pry"
require "csv"
require "yaml"

class MainProcess
  LAST_CRAWLED_INFO_FILE = File.dirname(__FILE__) + "/../tmp/last_crawled_info.yml"

  class << self
    def init_selenium_driver
      Log.info "Init driver: will take more than 20 seconds"

      system "open -a /Applications/Tor\\ Browser.app"
      sleep 20
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

    def quit_driver driver
      driver.quit
      system "ps -A | grep \"/Applications/Tor Browser.app/Contents/MacOS/[firefox]\" | awk '{print $1}' > ./tmp/pid.txt"
      pid = File.open("./tmp/pid.txt", "r"){|f| f.readline}.to_i
      system "kill -9 #{pid}"
    end

    def call!
        baseconnect_home_page = "https://baseconnect.in"

        Log.info "Start to craw data"
        driver = init_selenium_driver
        home_headlinks = get_all_home_headlinks

        setting = read_setting
        last_info = read_last_crawled_info setting

        (last_info[:category_index]..setting["end_category_index"]).each do |index|
            Log.info "------------------------------------------------------------"
            home_headlink = home_headlinks.find{|h| h[:index] == index }
            craw_for_a_category home_headlink, index, driver, last_info
        end

        # craw_for_a_category home_headlinks.first, 0, driver

        sleep 10

        quit_driver driver
        Log.info "End MainProcess#call!"
    end

    def read_last_crawled_info(setting)
      Log.info "Get last crawled info"

      info = if File.exists?(LAST_CRAWLED_INFO_FILE)
        YAML.load_file(LAST_CRAWLED_INFO_FILE)
      else
        {
          category_index: setting[:start_category_index.to_s],
          last_page: setting[:start_page.to_s] - 1
        }
      end

      category_index = info[:category_index]
      category_info = get_all_home_headlinks[category_index]

      Log.info "\tCategory index: #{category_info[:index]}"
      Log.info "\tParent category name: #{category_info[:big_category_name]}"
      Log.info "\tCategory name: #{category_info[:category_name]}"
      Log.info "\tExpected number of records: #{category_info[:quantity]}"

      return info
    end

    def read_setting
      Log.info "Read setting.yml"
      setting_file = "./setting.yml"
      raise StandardError.new("setting.yml is not existed") unless File.exists?(setting_file)

      YAML.load_file(setting_file)
    end

    def craw_for_a_category home_headlink, index, driver, last_info
        baseconnect_companies_list = []
        result = []
        max_page = 200

        # If failure, please read file
        start_page = last_info[:last_page] + 1
        count = 0

        Log.info "Category index: #{home_headlink[:index]}"
        Log.info "Parent category name: #{home_headlink[:big_category_name]}"
        Log.info "Category name: #{home_headlink[:category_name]}"
        Log.info "Expected number of records: #{home_headlink[:quantity]}"

        (start_page..max_page).each do |page|
            category_index_link = home_headlink[:link] + (page == 1 ? "" : "?page=#{page}")
            Log.info "Page: #{page}"
            Log.info "#{index + 1}:\t#{page}\tAccess to #{category_index_link}"
            driver.get category_index_link
            Log.info "\t\tRetrieve companies link"

            elements = driver.find_elements(:css, ".searches__result__list__header__title a")

            if elements.empty?
              quit_driver driver
              driver = init_selenium_driver
            end

            baseconnect_companies_list = elements.map do |element|
                {
                    name: element.attribute("innerHTML"),
                    detail_link: element.attribute("href")
                }
            end

            baseconnect_companies_list.each_with_index do |company, cp_index|
                result << craw_a_company(company, index, page, driver, home_headlink, cp_index)
                count = count + 1
            end
            #result << craw_a_company(baseconnect_companies_list.first, 0, page, driver, home_headlink)

            Log.info "#{index + 1}:\t#{page}:\tCrawed companies count: #{baseconnect_companies_list.size}"

            write_to_spread_sheet home_headlink, result, index, page

            File.open(LAST_CRAWLED_INFO_FILE, "w") do |file|
              last_info = {
                category_index: index,
                last_page: page
              }
              file.write(last_info.to_yaml)
            end

            baseconnect_companies_list.clear
            result.clear

            if count >= home_headlink[:quantity] - 1
              break
            end
        end
    end

    def craw_a_company company, index, page, driver, home_headlink, cp_index
        Log.info "#{index + 1}:\t#{page}:\t#{cp_index}\tCraw #{company[:name]}"
        Log.info "#{index + 1}:\t#{page}:\t#{cp_index}\t\t□ Access to #{company[:detail_link]}"
        driver.get(company[:detail_link])
        name = driver.find_elements(:css, ".node__header__text__title").first&.attribute("innerHTML").to_s

        if name.empty?
          quit_driver driver
          driver = init_selenium_driver
        end

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
            province: address.split(/都|県|道/)[0]
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

    def get_all_home_headlinks
        Log.info "Get all home_headlinks"

        [
            {index: 1, big_category_name:  "小売業界の会社", name: "自社型eコマース業界の会社", link: "https://baseconnect.in/companies/category/d861bd35-0830-4312-a872-443007e18e09", quantity: 33109},
            {index: 2, big_category_name:  "小売業界の会社", name: "中古車販売業界の会社", link: "https://baseconnect.in/companies/category/d2303f24-85a0-4bf6-80a4-9512b1efaede", quantity: 21908},
            {index: 3, big_category_name:  "小売業界の会社", name: "その他小売業界の会社", link: "https://baseconnect.in/companies/category/949a2d4e-5642-4e5f-bed9-a96a6df0a10f", quantity: 18674},
            {index: 4, big_category_name:  "小売業界の会社", name: "新車販売業界の会社", link: "https://baseconnect.in/companies/category/a67ead42-fdf3-40b0-8e8f-fb3f79ebea52", quantity: 17404},
            {index: 5, big_category_name:  "小売業界の会社", name: "モール型eコマース業界の会社", link: "https://baseconnect.in/companies/category/1441892b-d4fd-4c6d-b535-4b3e84d04d75", quantity: 17014},
            {index: 6, big_category_name:  "小売業界の会社", name: "食品店業界の会社", link: "https://baseconnect.in/companies/category/7253fd01-e6ea-4734-ad2a-8d2ff2c1cbfa", quantity: 10925},
            {index: 7, big_category_name:  "小売業界の会社", name: "自動車部品・カー用品販売業界の会社", link: "https://baseconnect.in/companies/category/87501685-5080-49fc-804d-411ec0bdf063", quantity: 7035},
            {index: 8, big_category_name:  "小売業界の会社", name: "家具販売業界の会社", link: "https://baseconnect.in/companies/category/1b199f49-b05f-4ca0-a581-fe8c7171667f", quantity: 6717},
            {index: 9, big_category_name:  "小売業界の会社", name: "ガソリンスタンド業界の会社", link: "https://baseconnect.in/companies/category/56f7a64c-dee6-4dcc-a455-11ff0cd8f9c3", quantity: 6530},
            {index: 10, big_category_name:  "小売業界の会社", name: "化粧品販売業界の会社", link: "https://baseconnect.in/companies/category/423071f5-60f6-485b-ab43-4d9853b61763", quantity: 5141},
            {index: 11, big_category_name:  "小売業界の会社", name: "作業関連用品販売業界の会社", link: "https://baseconnect.in/companies/category/31929f2f-96af-4cc4-a304-5d9f9806ab02", quantity: 4780},
            {index: 12, big_category_name:  "小売業界の会社", name: "花屋業界の会社", link: "https://baseconnect.in/companies/category/689a9407-5e8b-4670-b8da-a6ddc85bb588", quantity: 3902},
            {index: 13, big_category_name:  "小売業界の会社", name: "スポーツ用品販売業界の会社", link: "https://baseconnect.in/companies/category/410a3cec-5c74-41e9-96a8-2fea8030b03b", quantity: 3581},
            {index: 14, big_category_name:  "小売業界の会社", name: "メンズアパレルショップ業界の会社", link: "https://baseconnect.in/companies/category/1c7fcad0-478f-46d2-8777-7f3604432c77", quantity: 3214},
            {index: 15, big_category_name:  "小売業界の会社", name: "古本・リサイクルショップ業界の会社", link: "https://baseconnect.in/companies/category/8ae4241a-47b9-4e36-89cd-772ed74e256c", quantity: 2929},
            {index: 16, big_category_name:  "小売業界の会社", name: "小売店舗・施設業界の会社", link: "https://baseconnect.in/companies/category/d0e7d9fe-80f5-45fc-8506-cb1af5eec486", quantity: 2860},
            {index: 17, big_category_name:  "小売業界の会社", name: "その他アパレルショップ業界の会社", link: "https://baseconnect.in/companies/category/c406dd6e-1a27-4c0b-8427-7828ad769dda", quantity: 2736},
            {index: 18, big_category_name:  "小売業界の会社", name: "ジュエリーショップ業界の会社", link: "https://baseconnect.in/companies/category/d52a3c37-9345-4c1b-91d8-61acba63e1b0", quantity: 2621},
            {index: 19, big_category_name:  "小売業界の会社", name: "その他自動車販売業界の会社", link: "https://baseconnect.in/companies/category/25b30dda-2de7-43a3-942e-f8795bfd2cc5", quantity: 2194},
            {index: 20, big_category_name:  "小売業界の会社", name: "書籍・マルチメディア販売業界の会社", link: "https://baseconnect.in/companies/category/018ff9af-2781-4117-8073-bf2277fca057", quantity: 2126},
            {index: 21, big_category_name:  "小売業界の会社", name: "スーパーマーケット業界の会社", link: "https://baseconnect.in/companies/category/837f7cdb-c20b-4507-90a1-fe1fb03a4928", quantity: 1763},
            {index: 22, big_category_name:  "小売業界の会社", name: "パソコン・スマホ周辺機器販売業界の会社", link: "https://baseconnect.in/companies/category/0fce2f10-4e2c-492a-9db0-30606371d3d7", quantity: 1718},
            {index: 23, big_category_name:  "小売業界の会社", name: "医薬品販売業界の会社", link: "https://baseconnect.in/companies/category/b694a7e2-9201-4bf3-93ac-51093da9627a", quantity: 1686},
            {index: 24, big_category_name:  "小売業界の会社", name: "眼鏡・コンタクトレンズ販売業界の会社", link: "https://baseconnect.in/companies/category/af7d2887-e96f-49b8-9222-86d06ade2c76", quantity: 1529},
            {index: 25, big_category_name:  "小売業界の会社", name: "美容グッズ販売業界の会社", link: "https://baseconnect.in/companies/category/a832977e-e93f-4317-9b3b-562518fb6223", quantity: 1516},
            {index: 26, big_category_name:  "小売業界の会社", name: "キッズアパレルショップ業界の会社", link: "https://baseconnect.in/companies/category/c5869989-e007-44f7-a5c6-40f9ede774ab", quantity: 1114},
            {index: 27, big_category_name:  "小売業界の会社", name: "乳製品宅配業界の会社", link: "https://baseconnect.in/companies/category/1ae41140-a0ae-473a-b410-541e531cee64", quantity: 598},
            {index: 28, big_category_name:  "不動産業界の会社", name: "マンション・アパート賃貸業界の会社", link: "https://baseconnect.in/companies/category/d3fb2269-3c68-43dd-b7a8-d36576740641", quantity: 31915},
            {index: 29, big_category_name:  "不動産業界の会社", name: "マンション・アパート売買業界の会社", link: "https://baseconnect.in/companies/category/48ec10ab-8525-46fa-9b02-50552d6ec76c", quantity: 27828},
            {index: 30, big_category_name:  "不動産業界の会社", name: "その他不動産業界", link: "https://baseconnect.in/companies/category/dbd1c236-96a0-4cea-b53e-5616d5add040", quantity: 25525},
            {index: 31, big_category_name:  "不動産業界の会社", name: "事業用物件・テナントビル賃貸業界の会社", link: "https://baseconnect.in/companies/category/dc46f5a2-c8d5-4f50-bb09-fd3fe8a8e058", quantity: 25364},
            {index: 32, big_category_name:  "不動産業界の会社", name: "戸建売買業界の会社", link: "https://baseconnect.in/companies/category/f750f671-7022-4606-8236-34df3f821a42", quantity: 25298},
            {index: 33, big_category_name:  "不動産業界の会社", name: "戸建賃貸業界の会社", link: "https://baseconnect.in/companies/category/822869bd-9ef7-40e7-bf7b-3ae8dbb1b87e", quantity: 16880},
            {index: 34, big_category_name:  "不動産業界の会社", name: "土地売買・賃貸業界の会社", link: "https://baseconnect.in/companies/category/7331dec4-a2b5-4211-94db-9e1d1ec493a7", quantity: 14307},
            {index: 35, big_category_name:  "不動産業界の会社", name: "その他不動産管理業界の会社", link: "https://baseconnect.in/companies/category/558bcc0f-8254-4dd6-8f63-70c85aff8a73", quantity: 14159},
            {index: 36, big_category_name:  "不動産業界の会社", name: "事業用物件・テナントビル売買業界の会社", link: "https://baseconnect.in/companies/category/8316eb7e-16bf-4921-9053-95aab2bb7321", quantity: 13518},
            {index: 37, big_category_name:  "不動産業界の会社", name: "マンション・ビル管理業界の会社", link: "https://baseconnect.in/companies/category/443f8992-3fb4-4b0d-8527-eede51a7a615", quantity: 10879},
            {index: 38, big_category_name:  "不動産業界の会社", name: "駐車場運営業界の会社", link: "https://baseconnect.in/companies/category/a8963ab4-1937-4ba9-b068-ed9a74dce84a", quantity: 3611},
            {index: 39, big_category_name:  "不動産業界の会社", name: "レンタルスペース業界の会社", link: "https://baseconnect.in/companies/category/ba2148b9-c79c-4b98-ac6e-e7cd2b4f0ba8", quantity: 2454},
            {index: 40, big_category_name:  "不動産業界の会社", name: "総合不動産（デベロッパー）業界の会社", link: "https://baseconnect.in/companies/category/f38b7e17-588a-4f3d-8cca-1f18c92caf15", quantity: 157},
            {index: 41, big_category_name:  "商社業界の会社", name: "その他専門商社業界の会社", link: "https://baseconnect.in/companies/category/fe802cad-b81f-4ca8-9356-8ea1a3331a3a", quantity: 18633},
            {index: 42, big_category_name:  "商社業界の会社", name: "建材専門商社業界の会社", link: "https://baseconnect.in/companies/category/ca65e2d1-2a48-45c8-ae2b-7f5a95a88c77", quantity: 12175},
            {index: 43, big_category_name:  "商社業界の会社", name: "その他機械専門商社業界の会社", link: "https://baseconnect.in/companies/category/7a1b129e-7245-44f9-b4ef-8c5903baeff1", quantity: 9012},
            {index: 44, big_category_name:  "商社業界の会社", name: "その他食品専門商社業界の会社", link: "https://baseconnect.in/companies/category/52ee4f87-9cb4-4708-a34a-e589e59bb966", quantity: 6743},
            {index: 45, big_category_name:  "商社業界の会社", name: "工業用機械専門商社業界の会社", link: "https://baseconnect.in/companies/category/734a9cdf-b2af-4609-bb92-3ab7aadc0638", quantity: 6177},
            {index: 46, big_category_name:  "商社業界の会社", name: "農産物食品専門商社業界の会社", link: "https://baseconnect.in/companies/category/96a84420-94bd-468f-80ca-ed6988a12a18", quantity: 4932},
            {index: 47, big_category_name:  "商社業界の会社", name: "水産物食品専門商社業界の会社", link: "https://baseconnect.in/companies/category/cc92daef-d59f-4809-beb2-938b723a8ea5", quantity: 4015},
            {index: 48, big_category_name:  "商社業界の会社", name: "繊維・アパレル専門商社業界の会社", link: "https://baseconnect.in/companies/category/3cf7e0ef-f5ee-40da-8297-3b031b5d47d0", quantity: 3334},
            {index: 49, big_category_name:  "商社業界の会社", name: "日用品・化粧品専門商社業界の会社", link: "https://baseconnect.in/companies/category/74b680b5-1ddc-4c19-9576-524792e7f802", quantity: 3181},
            {index: 50, big_category_name:  "商社業界の会社", name: "化学品・医薬品専門商社業界の会社", link: "https://baseconnect.in/companies/category/38b4e776-8575-4910-9f7b-f6e045b7676f", quantity: 2963},
            {index: 51, big_category_name:  "商社業界の会社", name: "医療機器・器具専門商社業界の会社", link: "https://baseconnect.in/companies/category/b2358a1c-c4c6-46f4-a0b1-dee3a1b30a0b", quantity: 2873},
            {index: 52, big_category_name:  "商社業界の会社", name: "鉄鋼・金属専門商社業界の会社", link: "https://baseconnect.in/companies/category/3ac880b6-d5be-471c-8b33-28aa1deee133", quantity: 2376},
            {index: 53, big_category_name:  "商社業界の会社", name: "雑貨専門商社の会社", link: "https://baseconnect.in/companies/category/23340d32-1f01-4d9b-b7af-c70f520f258e", quantity: 1698},
            {index: 54, big_category_name:  "商社業界の会社", name: "食肉・卵専門商社業界の会社", link: "https://baseconnect.in/companies/category/3464d764-62d8-421c-a42f-a579f195d7a8", quantity: 1673},
            {index: 55, big_category_name:  "商社業界の会社", name: "農林水産用機械専門商社業界の会社", link: "https://baseconnect.in/companies/category/877ecd88-823f-4f2f-8628-c97bb0f5c8c5", quantity: 1588},
            {index: 56, big_category_name:  "商社業界の会社", name: "電子部品専門商社業界の会社", link: "https://baseconnect.in/companies/category/50dc7ec6-65a8-4e26-b9b1-b333722bd9d0", quantity: 1361},
            {index: 57, big_category_name:  "商社業界の会社", name: "紙・パルプ専門商社業界の会社", link: "https://baseconnect.in/companies/category/85832996-e950-4145-bda6-cb59b4e698bf", quantity: 902},
            {index: 58, big_category_name:  "商社業界の会社", name: "総合商社業界の会社", link: "https://baseconnect.in/companies/category/979e05d1-815e-4dda-b5a4-a481f9255cec", quantity: 72},
            {index: 59, big_category_name:  "自動車・乗り物業界の会社", name: "自動車整備業界の会社", link: "https://baseconnect.in/companies/category/0606cd3a-4e04-4116-a6bc-475df0b3df97", quantity: 35954},
            {index: 60, big_category_name:  "自動車・乗り物業界の会社", name: "自動車部品・カー用品製造業界の会社", link: "https://baseconnect.in/companies/category/eac932a7-5352-4e4d-9616-e1adbe02dab6", quantity: 12085},
            {index: 61, big_category_name:  "自動車・乗り物業界の会社", name: "レンタカー・リース業界の会社", link: "https://baseconnect.in/companies/category/9070f67a-baaf-48c8-b8be-0c6405714005", quantity: 5164},
            {index: 62, big_category_name:  "自動車・乗り物業界の会社", name: "二輪車(自転車・バイク)業界の会社", link: "https://baseconnect.in/companies/category/c1ff0313-586f-4a59-84a1-a1e606e580df", quantity: 3635},
            {index: 63, big_category_name:  "自動車・乗り物業界の会社", name: "その他乗り物業界の会社", link: "https://baseconnect.in/companies/category/4a89381c-fdd1-402e-95a5-ab4f7ca589b0", quantity: 3190},
            {index: 64, big_category_name:  "自動車・乗り物業界の会社", name: "ゴム製品・タイヤ製造業界の会社", link: "https://baseconnect.in/companies/category/3bf79440-c138-4002-950a-c4e039a9f0b3", quantity: 2153},
            {index: 65, big_category_name:  "自動車・乗り物業界の会社", name: "その他自動車・乗り物関連サービス業界の会社", link: "https://baseconnect.in/companies/category/0d22c125-928d-4aa8-a319-0a76755d72dc", quantity: 1823},
            {index: 66, big_category_name:  "自動車・乗り物業界の会社", name: "自動車製造業界の会社", link: "https://baseconnect.in/companies/category/ea1b1d82-f713-45da-b755-ffc9c6e57cb1", quantity: 397},
            {index: 67, big_category_name:  "自動車・乗り物業界の会社", name: "宇宙開発業界の会社", link: "https://baseconnect.in/companies/category/60cbd236-7f72-4366-aa1f-617b9a0d4ff7", quantity: 96},
            {index: 68, big_category_name:  "機械業界の会社", name: "その他機械製造業界の会社", link: "https://baseconnect.in/companies/category/a0172a58-8948-43ed-8ab6-225f98349eaa", quantity: 8487},
            {index: 69, big_category_name:  "機械業界の会社", name: "金型製造業界の会社", link: "https://baseconnect.in/companies/category/767226a3-66d7-4af9-a70c-0c4af552ac4a", quantity: 6642},
            {index: 70, big_category_name:  "機械業界の会社", name: "電子部品製造業界の会社", link: "https://baseconnect.in/companies/category/e2ef8700-1499-4bba-b848-1ca8a8899138", quantity: 5704},
            {index: 71, big_category_name:  "機械業界の会社", name: "工作機械製造業界の会社", link: "https://baseconnect.in/companies/category/6af30968-b08b-4049-9f1d-234941a21903", quantity: 4770},
            {index: 72, big_category_name:  "機械業界の会社", name: "産業用ロボット・ファクトリーオートメーション製造業界の会社", link: "https://baseconnect.in/companies/category/5c66e459-937a-40ef-9829-9c9e4bee0e6a", quantity: 3915},
            {index: 73, big_category_name:  "機械業界の会社", name: "精密機器製造業界の会社", link: "https://baseconnect.in/companies/category/82d886c1-11b9-4b81-8cfa-e81fcf9be1ba", quantity: 2697},
            {index: 74, big_category_name:  "機械業界の会社", name: "工具製造業界の会社", link: "https://baseconnect.in/companies/category/41aa30d3-69b6-47f4-9f5a-a622a7ae8d8e", quantity: 2666},
            {index: 75, big_category_name:  "機械業界の会社", name: "センサー・計器製造業界の会社", link: "https://baseconnect.in/companies/category/51d45720-bfc6-4480-8daf-ee438fc04070", quantity: 2443},
            {index: 76, big_category_name:  "機械業界の会社", name: "半導体・半導体関連装置製造業界の会社", link: "https://baseconnect.in/companies/category/6f462832-ae7d-481f-b130-ce050bc9635d", quantity: 1812},
            {index: 77, big_category_name:  "機械業界の会社", name: "動力装置製造業界の会社", link: "https://baseconnect.in/companies/category/e740a201-a52d-4cd6-a761-6d180d44442d", quantity: 1802},
            {index: 78, big_category_name:  "機械業界の会社", name: "電力設備・発電設備製造業界の会社", link: "https://baseconnect.in/companies/category/c07f653c-d125-4e9b-acd6-0b1f01473d9d", quantity: 1762},
            {index: 79, big_category_name:  "機械業界の会社", name: "建設機械製造業界の会社", link: "https://baseconnect.in/companies/category/0f7f0667-54ba-4a12-9a39-76575a6b795c", quantity: 1401},
            {index: 80, big_category_name:  "機械業界の会社", name: "水処理機械製造業界の会社", link: "https://baseconnect.in/companies/category/d319151f-5be4-43bf-8619-47882e2845ba", quantity: 1320},
            {index: 81, big_category_name:  "機械業界の会社", name: "食品機械製造業界の会社", link: "https://baseconnect.in/companies/category/5b681f97-c14a-4f9e-8900-e2e1d0d8396d", quantity: 1317},
            {index: 82, big_category_name:  "機械業界の会社", name: "自動販売機・自動サービス機業界の会社", link: "https://baseconnect.in/companies/category/2276f421-b805-4b9e-98f2-b74519bd2591", quantity: 1083},
            {index: 83, big_category_name:  "機械業界の会社", name: "空調機器業界の会社", link: "https://baseconnect.in/companies/category/072454c0-1d53-4a2d-8372-4bd94c91cc3e", quantity: 1073},
            {index: 84, big_category_name:  "機械業界の会社", name: "業務厨房関連機器製造業界の会社", link: "https://baseconnect.in/companies/category/366f0be4-5217-40d5-bf23-b40c930e512c", quantity: 1006},
            {index: 85, big_category_name:  "機械業界の会社", name: "アミューズメント機器業界の会社", link: "https://baseconnect.in/companies/category/d026fc8c-4a95-4eda-843f-9ffeed543761", quantity: 811},
            {index: 86, big_category_name:  "機械業界の会社", name: "光学機器・レンズ製造業界の会社", link: "https://baseconnect.in/companies/category/d6e2ca30-a444-453a-a50e-ccf7c8dc93b5", quantity: 780},
            {index: 87, big_category_name:  "機械業界の会社", name: "農業・漁業機械製造業界の会社", link: "https://baseconnect.in/companies/category/0158bde7-c609-4538-9d81-f1ee90d49538", quantity: 749},
            {index: 88, big_category_name:  "機械業界の会社", name: "試験機製造業界の会社", link: "https://baseconnect.in/companies/category/5d271acc-f954-45fd-98d9-a00cfa28b2ee", quantity: 728},
            {index: 89, big_category_name:  "機械業界の会社", name: "交通機器製造業界の会社", link: "https://baseconnect.in/companies/category/366fca69-f208-4fda-94cc-e569ea25d95e", quantity: 719},
            {index: 90, big_category_name:  "機械業界の会社", name: "ポンプ製造業界の会社", link: "https://baseconnect.in/companies/category/645baadd-cb80-457c-9e26-e4f721a87688", quantity: 657},
            {index: 91, big_category_name:  "機械業界の会社", name: "印刷機械製造業界の会社", link: "https://baseconnect.in/companies/category/42b84222-7798-4d9c-8c8f-ae7caaff7f14", quantity: 646},
            {index: 92, big_category_name:  "機械業界の会社", name: "エレベーター・エスカレーター業界の会社", link: "https://baseconnect.in/companies/category/208be57e-ef69-4f9b-bfee-7edc3ad366f5", quantity: 621},
            {index: 93, big_category_name:  "機械業界の会社", name: "非金属加工機械製造業界の会社", link: "https://baseconnect.in/companies/category/83f48d7a-b05a-40ec-b483-36234e847a81", quantity: 435},
            {index: 94, big_category_name:  "機械業界の会社", name: "ボイラー製造業界の会社", link: "https://baseconnect.in/companies/category/b4fa354a-536d-4a70-a3cd-55f9e3496140", quantity: 405},
            {index: 95, big_category_name:  "機械業界の会社", name: "化学機械製造業界の会社", link: "https://baseconnect.in/companies/category/9df522c7-6a46-43b1-b7e7-816dff5dab71", quantity: 403},
            {index: 96, big_category_name:  "機械業界の会社", name: "溶接機械製造業界の会社", link: "https://baseconnect.in/companies/category/5ac5de7d-06a6-4dbf-90c4-bbcf95623a7f", quantity: 308},
            {index: 97, big_category_name:  "機械業界の会社", name: "プラスチック成形機械製造業界の会社", link: "https://baseconnect.in/companies/category/df8b7813-a93a-4f14-8c32-2df3c9fd664c", quantity: 244},
            {index: 98, big_category_name:  "エンタメ業界の会社", name: "イベント業界の会社", link: "https://baseconnect.in/companies/category/d943916d-ae4b-45cf-b64d-c38ef5346a39", quantity: 10301},
            {index: 99, big_category_name:  "エンタメ業界の会社", name: "ホテル・旅館業界の会社", link: "https://baseconnect.in/companies/category/3541135c-9a5a-44a4-8ec0-2c08efdf622c", quantity: 7675},
            {index: 100, big_category_name:  "エンタメ業界の会社", name: "映像・CM制作業界の会社", link: "https://baseconnect.in/companies/category/c90aa02c-64fa-43db-a511-d63b1466c6a1", quantity: 6437},
            {index: 101, big_category_name:  "エンタメ業界の会社", name: "その他エンタメ業界の会社", link: "https://baseconnect.in/companies/category/1de1333c-1020-41a8-a4ed-0c1f29663a3f", quantity: 5312},
            {index: 102, big_category_name:  "エンタメ業界の会社", name: "ペット・動物業界の会社", link: "https://baseconnect.in/companies/category/4e2b83b9-6983-4009-a870-a5b6e15868cf", quantity: 3915},
            {index: 103, big_category_name:  "エンタメ業界の会社", name: "国内旅行業界の会社", link: "https://baseconnect.in/companies/category/af9b3ada-7f01-4c6b-88de-134018471290", quantity: 3646},
            {index: 104, big_category_name:  "エンタメ業界の会社", name: "CD等マルチメディア・楽器業界の会社", link: "https://baseconnect.in/companies/category/362039f5-5774-402b-95a9-c487bf607b21", quantity: 3018},
            {index: 105, big_category_name:  "エンタメ業界の会社", name: "芸能プロダクション業界の会社", link: "https://baseconnect.in/companies/category/69f5f1c6-ad86-46f8-8e8f-14794c32470b", quantity: 2601},
            {index: 106, big_category_name:  "エンタメ業界の会社", name: "海外旅行・留学業界の会社", link: "https://baseconnect.in/companies/category/f23d6d2c-de8c-47b4-9c08-b19ec202db03", quantity: 2572},
            {index: 107, big_category_name:  "エンタメ業界の会社", name: "ジム・フィットネスクラブ業界の会社", link: "https://baseconnect.in/companies/category/b13fc5c4-b8d8-47db-a80e-3814219da1ee", quantity: 2096},
            {index: 108, big_category_name:  "エンタメ業界の会社", name: "ゴルフ場業界の会社", link: "https://baseconnect.in/companies/category/de5e0a0c-41e8-47da-a3fe-87d6243b69e9", quantity: 1873},
            {index: 109, big_category_name:  "エンタメ業界の会社", name: "パチンコ店運営業界の会社", link: "https://baseconnect.in/companies/category/3bdfca54-8460-4083-a20e-6cfa87f61372", quantity: 1257},
            {index: 110, big_category_name:  "エンタメ業界の会社", name: "映画・アニメ業界の会社", link: "https://baseconnect.in/companies/category/1536b372-85b1-4f8a-86af-f000f57377ef", quantity: 887},
            {index: 111, big_category_name:  "エンタメ業界の会社", name: "スポーツ業界の会社", link: "https://baseconnect.in/companies/category/643543d4-9b3b-436e-a464-27738e16a6dd", quantity: 461},
            {index: 112, big_category_name:  "エンタメ業界の会社", name: "タレント・キャラクターグッズ業界の会社", link: "https://baseconnect.in/companies/category/5d79c2ba-5d16-4c88-8a45-4d59f8f225f9", quantity: 361},
            {index: 113, big_category_name:  "生活用品業界の会社", name: "日用品・雑貨販売業界の会社", link: "https://baseconnect.in/companies/category/3db74a79-3ea2-4e50-bdcf-2dd5f0248002", quantity: 11388},
            {index: 114, big_category_name:  "生活用品業界の会社", name: "家具製造業界の会社", link: "https://baseconnect.in/companies/category/1c9316ff-23bf-48e1-8090-9ccdaffca599", quantity: 4778},
            {index: 115, big_category_name:  "生活用品業界の会社", name: "雑貨製造業界の会社", link: "https://baseconnect.in/companies/category/0c5c3e58-42d5-4c72-b659-a1809c3ceda3", quantity: 4586},
            {index: 116, big_category_name:  "生活用品業界の会社", name: "オフィス用品・オフィス家具業界の会社", link: "https://baseconnect.in/companies/category/0b7bf0be-4e99-4c45-b871-cf975dfe6a51", quantity: 3935},
            {index: 117, big_category_name:  "生活用品業界の会社", name: "美術品・伝統工芸品業界の会社", link: "https://baseconnect.in/companies/category/8f5618ad-c27f-4fb8-b2df-ead02e53d0ba", quantity: 3763},
            {index: 118, big_category_name:  "生活用品業界の会社", name: "文房具業界の会社", link: "https://baseconnect.in/companies/category/1b68d7db-7391-4292-8cc5-cb044ad0ef5e", quantity: 3578},
            {index: 119, big_category_name:  "生活用品業界の会社", name: "お土産・ギフト業界の会社", link: "https://baseconnect.in/companies/category/8ce51159-7611-42ba-869f-56aa153fe389", quantity: 3444},
            {index: 120, big_category_name:  "生活用品業界の会社", name: "仏具業界の会社", link: "https://baseconnect.in/companies/category/e9d1a775-d26f-4fd3-a45f-9a5d368db85d", quantity: 1820},
            {index: 121, big_category_name:  "生活用品業界の会社", name: "スポーツ用品製造業界の会社", link: "https://baseconnect.in/companies/category/2ef7e498-2881-4e73-9675-3be3970235fd", quantity: 1777},
            {index: 122, big_category_name:  "生活用品業界の会社", name: "輸入雑貨販売業界の会社", link: "https://baseconnect.in/companies/category/1c4b5397-13a1-4a3b-bcb9-40d56db9a4fc", quantity: 1766},
            {index: 123, big_category_name:  "生活用品業界の会社", name: "玩具業界の会社", link: "https://baseconnect.in/companies/category/053aecee-6b51-4a40-a96c-12623b50a967", quantity: 1757},
            {index: 124, big_category_name:  "生活用品業界の会社", name: "店舗家具・什器業界の会社", link: "https://baseconnect.in/companies/category/21e8aa9f-7afb-4e19-b7e4-aadc0af9d12d", quantity: 1274},
            {index: 125, big_category_name:  "生活用品業界の会社", name: "日用品製造業界の会社", link: "https://baseconnect.in/companies/category/45e1bff4-253a-4a5d-9b03-21ee7ef2023e", quantity: 1074},
            {index: 126, big_category_name:  "生活用品業界の会社", name: "タバコ業界の会社", link: "https://baseconnect.in/companies/category/9c4be031-5a2d-40df-9b7b-576ce91484b8", quantity: 934},
            {index: 127, big_category_name:  "生活用品業界の会社", name: "トイレタリー製造業界の会社", link: "https://baseconnect.in/companies/category/f9d09889-4997-41aa-b136-71f3502a6964", quantity: 806},
            {index: 128, big_category_name:  "生活用品業界の会社", name: "眼鏡・コンタクトレンズ製造業界の会社", link: "https://baseconnect.in/companies/category/9d9f235e-ac55-489d-929c-011c7e906642", quantity: 525},
            {index: 129, big_category_name:  "生活用品業界の会社", name: "ベビー用品製造業界の会社", link: "https://baseconnect.in/companies/category/2585c6fb-b860-4cae-b784-25f592f0b9be", quantity: 236},
            {index: 130, big_category_name:  "生活用品業界の会社", name: "その他生活用品業界の会社", link: "https://baseconnect.in/companies/category/f2d7145a-4e8a-413b-8db5-b2664fb7354a", quantity: 234},
            {index: 131, big_category_name:  "アパレル・美容業界の会社", name: "美容サロン業界の会社", link: "https://baseconnect.in/companies/category/74de4309-b861-4883-955c-b4ae81798696", quantity: 6108},
            {index: 132, big_category_name:  "アパレル・美容業界の会社", name: "レディースアパレルショップ業界の会社", link: "https://baseconnect.in/companies/category/7f123ee2-3981-4407-b2de-3268a785fd6b", quantity: 5769},
            {index: 133, big_category_name:  "アパレル・美容業界の会社", name: "繊維加工・織布業界の会社", link: "https://baseconnect.in/companies/category/4e8e7675-eca4-4b10-9444-72bff27d75f7", quantity: 4807},
            {index: 134, big_category_name:  "アパレル・美容業界の会社", name: "レディースアパレルメーカー業界の会社", link: "https://baseconnect.in/companies/category/a232c1a4-87c9-49a9-a635-85c2d7f18807", quantity: 3983},
            {index: 135, big_category_name:  "アパレル・美容業界の会社", name: "その他アパレルメーカー業界の会社", link: "https://baseconnect.in/companies/category/4470ba97-5763-4946-9636-3e4a1786e6c5", quantity: 2623},
            {index: 136, big_category_name:  "アパレル・美容業界の会社", name: "化粧品製造業界の会社", link: "https://baseconnect.in/companies/category/114c0021-a73f-4088-a9c2-49fc0a06671e", quantity: 2419},
            {index: 137, big_category_name:  "アパレル・美容業界の会社", name: "エステサロン業界の会社", link: "https://baseconnect.in/companies/category/c1d1e1f7-d747-4685-b1b6-2401d0c1987b", quantity: 2305},
            {index: 138, big_category_name:  "アパレル・美容業界の会社", name: "メンズアパレルメーカー業界の会社", link: "https://baseconnect.in/companies/category/31e713d0-2f6b-4d7a-b70e-636164218bfb", quantity: 2198},
            {index: 139, big_category_name:  "アパレル・美容業界の会社", name: "バッグ・アパレル雑貨製造業界の会社", link: "https://baseconnect.in/companies/category/bbdba3fc-cbef-4bfe-a389-cb757087fad3", quantity: 1774},
            {index: 140, big_category_name:  "アパレル・美容業界の会社", name: "その他アパレル・美容業界の会社", link: "https://baseconnect.in/companies/category/a0734e86-1f0c-4c10-95fc-a099c1447567", quantity: 1618},
            {index: 141, big_category_name:  "アパレル・美容業界の会社", name: "ジュエリー製造業界の会社", link: "https://baseconnect.in/companies/category/34c6775f-5c31-4d30-909f-646a9ff6ea1a", quantity: 1497},
            {index: 142, big_category_name:  "アパレル・美容業界の会社", name: "制服・作業服製造業界の会社", link: "https://baseconnect.in/companies/category/b5cd3234-99cc-45b9-b95e-3d4768684fe0", quantity: 1385},
            {index: 143, big_category_name:  "アパレル・美容業界の会社", name: "スキンケア製品製造業界の会社", link: "https://baseconnect.in/companies/category/082f4c70-2641-4df0-b429-5cd210978fda", quantity: 1246},
            {index: 144, big_category_name:  "アパレル・美容業界の会社", name: "時計業界の会社", link: "https://baseconnect.in/companies/category/d0620238-a4f0-46c0-9c6f-537431114b44", quantity: 1238},
            {index: 145, big_category_name:  "アパレル・美容業界の会社", name: "靴製造・修理業界の会社", link: "https://baseconnect.in/companies/category/51b1af81-d396-4da1-b39a-d83637272aa0", quantity: 1114},
            {index: 146, big_category_name:  "アパレル・美容業界の会社", name: "キッズアパレルメーカー業界の会社", link: "https://baseconnect.in/companies/category/ce7bcdf3-562d-4935-830f-7caf2a6007c7", quantity: 945},
            {index: 147, big_category_name:  "アパレル・美容業界の会社", name: "下着・靴下製造業界の会社", link: "https://baseconnect.in/companies/category/db2fc5ec-ae6d-45da-b1f1-481493403727", quantity: 549},
            {index: 148, big_category_name:  "人材業界の会社", name: "その他業務請負業界の会社", link: "https://baseconnect.in/companies/category/5e54fc69-5530-4bb9-aef0-ab3981a9648d", quantity: 10918},
            {index: 149, big_category_name:  "人材業界の会社", name: "企業研修業界の会社", link: "https://baseconnect.in/companies/category/ab82d19d-2ced-4b5d-b70c-790c7b297110", quantity: 5933},
            {index: 150, big_category_name:  "人材業界の会社", name: "製造業・技術系人材派遣業界の会社", link: "https://baseconnect.in/companies/category/fb683792-5239-4acb-a6ef-dfbda6a447a9", quantity: 5264},
            {index: 151, big_category_name:  "人材業界の会社", name: "人材紹介業界の会社", link: "https://baseconnect.in/companies/category/f9b84fcc-6c97-49ae-8bc5-d083f794e25c", quantity: 5137},
            {index: 152, big_category_name:  "人材業界の会社", name: "事務処理代行業界の会社", link: "https://baseconnect.in/companies/category/1302de1e-49bf-4b96-a70e-a22d703c2eaf", quantity: 4076},
            {index: 153, big_category_name:  "人材業界の会社", name: "事務員・作業員派遣業界の会社", link: "https://baseconnect.in/companies/category/7b436065-c772-4f3e-93c2-25d3ef577318", quantity: 3414},
            {index: 154, big_category_name:  "人材業界の会社", name: "サービス業人材派遣業界の会社", link: "https://baseconnect.in/companies/category/203a7c03-b08b-46d1-bfb6-af739e4559d6", quantity: 2739},
            {index: 155, big_category_name:  "人材業界の会社", name: "個人向けセミナー業界", link: "https://baseconnect.in/companies/category/44662792-598a-4ce5-81f6-58297e7f453f", quantity: 2357},
            {index: 156, big_category_name:  "人材業界の会社", name: "その他人材業界の会社", link: "https://baseconnect.in/companies/category/a2d25557-de08-4fb0-a946-581721d660cd", quantity: 2246},
            {index: 157, big_category_name:  "人材業界の会社", name: "物流人材派遣業界の会社", link: "https://baseconnect.in/companies/category/d4988c7c-19c7-4a8d-9bac-6a42db803863", quantity: 1626},
            {index: 158, big_category_name:  "人材業界の会社", name: "医療・福祉人材派遣業界の会社", link: "https://baseconnect.in/companies/category/b204d2f4-7770-40bb-9e16-ff1aed380583", quantity: 1244},
            {index: 159, big_category_name:  "人材業界の会社", name: "コールセンター運営業界の会社", link: "https://baseconnect.in/companies/category/649e5ff3-cd1e-49df-8da9-3b2dd095c37b", quantity: 1026},
            {index: 160, big_category_name:  "機械関連サービス業界の会社", name: "機械修理業界の会社", link: "https://baseconnect.in/companies/category/f0d6f61d-23dd-4021-9a8f-054d2461cb1e", quantity: 9419},
            {index: 161, big_category_name:  "機械関連サービス業界の会社", name: "その他機械関連サービス業界の会社", link: "https://baseconnect.in/companies/category/578aaf92-7223-4a07-a735-25acc04e6df8", quantity: 5867},
            {index: 162, big_category_name:  "機械関連サービス業界の会社", name: "機械レンタル・リース業界の会社", link: "https://baseconnect.in/companies/category/045f88b2-8004-4d8c-8e78-6ea260042027", quantity: 4527},
            {index: 163, big_category_name:  "機械関連サービス業界の会社", name: "機械設計業界の会社", link: "https://baseconnect.in/companies/category/bfcc9f5f-ef59-4200-87bc-e27424bfed7b", quantity: 3062},
            {index: 164, big_category_name:  "機械関連サービス業界の会社", name: "プラントエンジニアリング業界の会社", link: "https://baseconnect.in/companies/category/eaa5286f-ab87-4ba9-8612-1285ac978ac0", quantity: 821},
            {index: 165, big_category_name:  "化学業界の会社", name: "樹脂製部品(プラスチック製部品など)製造業界の会社", link: "https://baseconnect.in/companies/category/cb6259b8-2e57-462f-912e-a840b7e67857", quantity: 5953},
            {index: 166, big_category_name:  "化学業界の会社", name: "樹脂製品(プラスチック製品など)製造業界の会社", link: "https://baseconnect.in/companies/category/ccfca32a-554f-4b18-a15f-5f1397fe044d", quantity: 5220},
            {index: 167, big_category_name:  "化学業界の会社", name: "肥料・農薬・ガーデニング用品製造業界の会社", link: "https://baseconnect.in/companies/category/3ad4a86c-e7fd-424a-a7ec-ddb6245f43ae", quantity: 3136},
            {index: 168, big_category_name:  "化学業界の会社", name: "化学品・化学薬品製造業界の会社", link: "https://baseconnect.in/companies/category/3f4bf701-d5eb-4a82-9e65-04de55607c56", quantity: 2871},
            {index: 169, big_category_name:  "化学業界の会社", name: "塗料製造業界の会社", link: "https://baseconnect.in/companies/category/a9327a6f-3b51-4176-8fa3-739035d765f6", quantity: 1223},
            {index: 170, big_category_name:  "化学業界の会社", name: "その他化学業界の会社", link: "https://baseconnect.in/companies/category/95257d5c-ad6d-4521-bd17-83359e607db9", quantity: 1153},
            {index: 171, big_category_name:  "化学業界の会社", name: "接着剤・テープ製造業界の会社", link: "https://baseconnect.in/companies/category/cbf4dff4-a7a4-4f6e-a48b-d307828eaa47", quantity: 508},
            {index: 172, big_category_name:  "エネルギー業界の会社", name: "ガス・燃料製品と原料採掘の会社", link: "https://baseconnect.in/companies/category/1e016598-ab41-483e-919c-245c00a99bfb", quantity: 9739},
            {index: 173, big_category_name:  "エネルギー業界の会社", name: "再生可能エネルギー業界の会社", link: "https://baseconnect.in/companies/category/8bc250a1-0362-4090-baef-a4c043d32e56", quantity: 1786},
            {index: 174, big_category_name:  "エネルギー業界の会社", name: "電力業界の会社", link: "https://baseconnect.in/companies/category/850f77cc-be26-493b-85a9-86ad98298de9", quantity: 759},
            {index: 175, big_category_name:  "エネルギー業界の会社", name: "その他エネルギー業界の会社", link: "https://baseconnect.in/companies/category/7f5dc0f0-9edf-421a-8e17-2e0828d7e766", quantity: 114},
            {index: 176, big_category_name:  "マスコミ業界の会社", name: "書籍出版業界の会社", link: "https://baseconnect.in/companies/category/684ecb15-0316-4eea-a5df-3bbc3daab1c8", quantity: 4022},
            {index: 177, big_category_name:  "マスコミ業界の会社", name: "雑誌出版業界の会社", link: "https://baseconnect.in/companies/category/132eb772-8a9d-42ce-8fab-567a3975d17c", quantity: 2163},
            {index: 178, big_category_name:  "マスコミ業界の会社", name: "テレビ番組制作業界の会社", link: "https://baseconnect.in/companies/category/c0ac12b6-167e-4002-888f-bc84ff9ffa60", quantity: 1864},
            {index: 179, big_category_name:  "マスコミ業界の会社", name: "新聞業界の会社", link: "https://baseconnect.in/companies/category/54c4cf7f-b737-42b5-b0e5-c9ce884fd20d", quantity: 1633},
            {index: 180, big_category_name:  "マスコミ業界の会社", name: "電子書籍出版業界の会社", link: "https://baseconnect.in/companies/category/a9ef0a07-d5d9-44fc-8b9c-19d4290c72cf", quantity: 888},
            {index: 181, big_category_name:  "マスコミ業界の会社", name: "テレビ・ラジオ放送局業界の会社", link: "https://baseconnect.in/companies/category/966a1274-a234-4bb2-b5e4-aba25523a674", quantity: 654},
            {index: 182, big_category_name:  "マスコミ業界の会社", name: "ラジオ番組制作業界の会社", link: "https://baseconnect.in/companies/category/5dbf7c32-f891-4998-b0c9-9e05478f07c4", quantity: 422},
            {index: 183, big_category_name:  "マスコミ業界の会社", name: "その他マスコミ業界", link: "https://baseconnect.in/companies/category/d43d696f-74f0-4a82-a2a6-bac34b03ef84", quantity: 77},
            {index: 184, big_category_name:  "通信業界の会社", name: "携帯・通信回線販売代理店業界の会社", link: "https://baseconnect.in/companies/category/6fb60895-3dd0-4e68-91cc-7d3c6cb648ea", quantity: 2273},
            {index: 185, big_category_name:  "通信業界の会社", name: "通信回線業界の会社", link: "https://baseconnect.in/companies/category/06adf9d1-bfe9-4332-9ec7-0b7c9be54344", quantity: 702},
            {index: 186, big_category_name:  "通信業界の会社", name: "その他通信業界の会社", link: "https://baseconnect.in/companies/category/a1fa2be2-dee8-4d6c-b4bb-6faad72c5a2d", quantity: 580},
            {index: 187, big_category_name:  "ゲーム業界の会社", name: "ソーシャルゲーム業界の会社", link: "https://baseconnect.in/companies/category/5e227ff5-308f-4cd8-955c-b5174189a70a", quantity: 982},
            {index: 188, big_category_name:  "ゲーム業界の会社", name: "ゲームソフト開発業界の会社", link: "https://baseconnect.in/companies/category/6d8b55ed-3e28-49b7-8c05-587833d73ca9", quantity: 734},
            {index: 189, big_category_name:  "ゲーム業界の会社", name: "ゲーム・アニメーション系デザイン業界の会社", link: "https://baseconnect.in/companies/category/2ac668d8-bc79-45ff-8b2e-24f8045fc784", quantity: 570},
            {index: 190, big_category_name:  "ゲーム業界の会社", name: "その他ゲーム業界の会社", link: "https://baseconnect.in/companies/category/d0741593-ba8e-4c34-96dd-f7cdddba42a3", quantity: 134},
            {index: 191, big_category_name:  "建設・工事業界の会社", name: "その他建築専門工事業界の会社", link: "https://baseconnect.in/companies/category/90d93623-c24e-499b-87d0-0a334ea5b368", quantity: 84741},
            {index: 192, big_category_name:  "建設・工事業界の会社", name: "その他土木工事業界の会社", link: "https://baseconnect.in/companies/category/c3a7d969-d95d-46c2-9556-71a8785c860d", quantity: 71330},
            {index: 193, big_category_name:  "建設・工事業界の会社", name: "居住用リフォーム業界の会社", link: "https://baseconnect.in/companies/category/146f80ba-4f8b-4f87-b05f-42a960de0d3e", quantity: 62152},
            {index: 194, big_category_name:  "建設・工事業界の会社", name: "衛生設備工事業界の会社", link: "https://baseconnect.in/companies/category/dd60c02b-9fd1-4c9f-b435-5b12c9b00f0a", quantity: 47723},
            {index: 195, big_category_name:  "建設・工事業界の会社", name: "その他建造物建築業界の会社", link: "https://baseconnect.in/companies/category/37e1b0c2-119d-4a37-8d22-cfc78d32676e", quantity: 47116},
            {index: 196, big_category_name:  "建設・工事業界の会社", name: "とび・土工工事業界の会社", link: "https://baseconnect.in/companies/category/d30a26df-7fd5-4740-8374-9e5ca3e4185c", quantity: 37830},
            {index: 197, big_category_name:  "建設・工事業界の会社", name: "交通関連土木工事業界の会社", link: "https://baseconnect.in/companies/category/4c14f538-57d5-4c00-82e0-ae13ec0304b9", quantity: 36322},
            {index: 198, big_category_name:  "建設・工事業界の会社", name: "注文型住宅建築業界の会社", link: "https://baseconnect.in/companies/category/f6ab66a7-dbab-45b1-8360-6427d8c6a344", quantity: 28592},
            {index: 199, big_category_name:  "建設・工事業界の会社", name: "その他電気設備工事業界の会社", link: "https://baseconnect.in/companies/category/4981132b-92cd-4900-970d-8ac0ed7ee6cf", quantity: 26574},
            {index: 200, big_category_name:  "建設・工事業界の会社", name: "住宅・事業所向け設備業界の会社", link: "https://baseconnect.in/companies/category/123d9301-88e7-4fbb-83e9-f5c574ce9e4c", quantity: 23374},
            {index: 201, big_category_name:  "建設・工事業界の会社", name: "空調設備工事業界の会社", link: "https://baseconnect.in/companies/category/4ed95de2-1d52-40a3-b9f2-b917eaea799e", quantity: 23061},
            {index: 202, big_category_name:  "建設・工事業界の会社", name: "事業用リフォーム業界の会社", link: "https://baseconnect.in/companies/category/838a9236-67b7-4293-8488-9957fcf5b403", quantity: 22351},
            {index: 203, big_category_name:  "建設・工事業界の会社", name: "土木・建築設計業界の会社", link: "https://baseconnect.in/companies/category/9315c115-358a-4cc9-a687-1a9e5f534fd5", quantity: 18645},
            {index: 204, big_category_name:  "建設・工事業界の会社", name: "建造物解体工事業界の会社", link: "https://baseconnect.in/companies/category/c2a729c6-0aa4-4362-b38f-2a7ef805264c", quantity: 18004},
            {index: 205, big_category_name:  "建設・工事業界の会社", name: "河川・港湾工事業界の会社", link: "https://baseconnect.in/companies/category/482a34dd-b0fd-4e2f-a555-96cf7056a6dd", quantity: 16791},
            {index: 206, big_category_name:  "建設・工事業界の会社", name: "太陽光パネル業界の会社", link: "https://baseconnect.in/companies/category/de04f7c8-788b-4401-9c1f-efb0b0e0e85b", quantity: 15309},
            {index: 207, big_category_name:  "建設・工事業界の会社", name: "造園工事業界の会社", link: "https://baseconnect.in/companies/category/b12d3ea4-dda5-4a53-b1eb-9172642249ea", quantity: 15162},
            {index: 208, big_category_name:  "建設・工事業界の会社", name: "産業用電気設備工事業界の会社", link: "https://baseconnect.in/companies/category/4d873014-59c4-4e8d-bc87-01b63f4f65f3", quantity: 13552},
            {index: 209, big_category_name:  "建設・工事業界の会社", name: "通信設備工事業界の会社", link: "https://baseconnect.in/companies/category/64b3990f-8ebf-4f7a-a623-11979ce61eda", quantity: 9309},
            {index: 210, big_category_name:  "建設・工事業界の会社", name: "その他リフォーム業界の会社", link: "https://baseconnect.in/companies/category/ba478caa-862e-4417-8e81-d3474cc06de5", quantity: 8503},
            {index: 211, big_category_name:  "建設・工事業界の会社", name: "窯業系建材・石材製造業界の会社", link: "https://baseconnect.in/companies/category/04678002-6831-4238-afd0-f3784e53f894", quantity: 8489},
            {index: 212, big_category_name:  "建設・工事業界の会社", name: "大型商業施設・公共施設建設業界の会社", link: "https://baseconnect.in/companies/category/3b5f31b3-f174-4ebf-88db-23ef172c8025", quantity: 6559},
            {index: 213, big_category_name:  "建設・工事業界の会社", name: "木材系建材製造業界の会社", link: "https://baseconnect.in/companies/category/c8d8735d-c86f-4775-9730-7bc78f971647", quantity: 6411},
            {index: 214, big_category_name:  "建設・工事業界の会社", name: "プラント設備工事業界の会社", link: "https://baseconnect.in/companies/category/6ceb8ebf-f79a-4b4e-a839-e2eb1b0aadfa", quantity: 5883},
            {index: 215, big_category_name:  "建設・工事業界の会社", name: "総合土木工事業界の会社", link: "https://baseconnect.in/companies/category/d31613b0-fa96-4b36-8956-dbf639f94439", quantity: 5590},
            {index: 216, big_category_name:  "建設・工事業界の会社", name: "金属系建材製造業界の会社", link: "https://baseconnect.in/companies/category/8f0938c5-067c-4090-91cd-10b86ced1f38", quantity: 5032},
            {index: 217, big_category_name:  "建設・工事業界の会社", name: "インテリアデザイン業界の会社", link: "https://baseconnect.in/companies/category/0cdb9e58-df07-4ccc-8f83-b315f70db10a", quantity: 4489},
            {index: 218, big_category_name:  "建設・工事業界の会社", name: "分譲型住宅建築業界の会社", link: "https://baseconnect.in/companies/category/adea1d06-603d-40d8-9251-1d8eeeaf0b7a", quantity: 4195},
            {index: 219, big_category_name:  "建設・工事業界の会社", name: "ビル建設業界の会社", link: "https://baseconnect.in/companies/category/647657c8-5e8e-4285-b6e5-50b26f0fce57", quantity: 2376},
            {index: 220, big_category_name:  "建設・工事業界の会社", name: "マンション建築業界の会社", link: "https://baseconnect.in/companies/category/f1db1e62-e792-4c0f-b41e-495503c4d28b", quantity: 2224},
            {index: 221, big_category_name:  "建設・工事業界の会社", name: "樹脂系建材製造業界の会社", link: "https://baseconnect.in/companies/category/08d3c909-a901-4ed7-b556-edeed41ba5f2", quantity: 986},
            {index: 222, big_category_name:  "建設・工事業界の会社", name: "ゼネコン業界の会社", link: "https://baseconnect.in/companies/category/0a5785c0-3ad8-47cc-988f-966f6593b8db", quantity: 180},
            {index: 223, big_category_name:  "建設・工事業界の会社", name: "燃料タンク工事業界の会社", link: "https://baseconnect.in/companies/category/0aec532b-ed16-4658-b1f0-4a38593e99dc", quantity: 162},
            {index: 224, big_category_name:  "その他サービス業界の会社", name: "廃棄物収集・運搬業界の会社", link: "https://baseconnect.in/companies/category/d6a8bf9b-fbda-485e-b08d-68bc17410859", quantity: 19690},
            {index: 225, big_category_name:  "その他サービス業界の会社", name: "デザイン業界の会社", link: "https://baseconnect.in/companies/category/d56261bf-9ed5-4ece-87f7-b74db9f6f407", quantity: 18328},
            {index: 226, big_category_name:  "その他サービス業界の会社", name: "Web制作業界の会社", link: "https://baseconnect.in/companies/category/b21f091d-597d-4584-ae7e-1a6ab2f54fcd", quantity: 17550},
            {index: 227, big_category_name:  "その他サービス業界の会社", name: "廃棄物処分業界の会社", link: "https://baseconnect.in/companies/category/2263adc3-c4cd-4d1a-9ff4-7694cb3bf1a7", quantity: 11082},
            {index: 228, big_category_name:  "その他サービス業界の会社", name: "ビル清掃・ハウスクリーニング業界の会社", link: "https://baseconnect.in/companies/category/ea2e31b5-3f9e-4d0a-bdd4-e4cbed781536", quantity: 10558},
            {index: 229, big_category_name:  "その他サービス業界の会社", name: "リサイクル業界の会社", link: "https://baseconnect.in/companies/category/9e935318-c163-46a4-8dee-e62f2fb3f104", quantity: 8690},
            {index: 230, big_category_name:  "その他サービス業界の会社", name: "調査・検査・研究業界の会社", link: "https://baseconnect.in/companies/category/d64acce7-95fd-4b20-8ae3-848bacc76dec", quantity: 8113},
            {index: 231, big_category_name:  "その他サービス業界の会社", name: "その他清掃業界の会社", link: "https://baseconnect.in/companies/category/e7e1417a-fb60-47c1-ac3e-1a858954f2ae", quantity: 7895},
            {index: 232, big_category_name:  "その他サービス業界の会社", name: "葬儀業界の会社", link: "https://baseconnect.in/companies/category/4df84e33-3676-4ead-b1f8-0f67cefd93d9", quantity: 7663},
            {index: 233, big_category_name:  "その他サービス業界の会社", name: "その他サービス業界", link: "https://baseconnect.in/companies/category/6c4c7570-d6f4-4aba-8d7e-7631ede90c7d", quantity: 6769},
            {index: 234, big_category_name:  "その他サービス業界の会社", name: "その他レンタル・リース業界の会社", link: "https://baseconnect.in/companies/category/0d10572d-b1b1-4a09-97f4-64c285b37360", quantity: 6231},
            {index: 235, big_category_name:  "その他サービス業界の会社", name: "警備業界の会社", link: "https://baseconnect.in/companies/category/764feebf-c835-4242-93fc-af257d4f8def", quantity: 5892},
            {index: 236, big_category_name:  "その他サービス業界の会社", name: "写真業界の会社", link: "https://baseconnect.in/companies/category/67a8351b-9f9e-4f2a-a8b5-14aca122dc98", quantity: 4111},
            {index: 237, big_category_name:  "その他サービス業界の会社", name: "クリーニング業界の会社", link: "https://baseconnect.in/companies/category/53669ddf-0e81-422e-9019-65515c9407a7", quantity: 3044},
            {index: 238, big_category_name:  "その他サービス業界の会社", name: "ブライダル業界の会社", link: "https://baseconnect.in/companies/category/671b6c14-3246-4f54-bdd0-41602e9e484f", quantity: 2864},
            {index: 239, big_category_name:  "その他サービス業界の会社", name: "生活関連レンタル・リース業界の会社", link: "https://baseconnect.in/companies/category/93d6e73a-767d-4e0b-bdc3-730b52c88a4d", quantity: 1593},
            {index: 240, big_category_name:  "その他サービス業界の会社", name: "遺品整理業界の会社", link: "https://baseconnect.in/companies/category/80463874-f213-4719-9316-469e6c349e5d", quantity: 1258},
            {index: 241, big_category_name:  "その他サービス業界の会社", name: "オフィス用品レンタル・リース業界の会社", link: "https://baseconnect.in/companies/category/bb9e32ff-7a8f-4434-91b0-eb5587c0bdb0", quantity: 1129},
            {index: 242, big_category_name:  "その他サービス業界の会社", name: "その他団体業界の会社", link: "https://baseconnect.in/companies/category/45a82f50-1294-46f3-8d66-f0aaf943cbfa", quantity: 126},
            {index: 243, big_category_name:  "製造業界の会社", name: "金属加工請負業界の会社", link: "https://baseconnect.in/companies/category/893138a6-6ef7-411a-b0c5-127e2d8d57d5", quantity: 27705},
            {index: 244, big_category_name:  "製造業界の会社", name: "金属部品製造業界の会社", link: "https://baseconnect.in/companies/category/febb2cac-3c7f-42d1-bd05-32d1acd72faf", quantity: 10666},
            {index: 245, big_category_name:  "製造業界の会社", name: "その他製造業界の会社", link: "https://baseconnect.in/companies/category/c430ce6e-62ae-4fde-94d2-7e9faa1ed0b6", quantity: 10342},
            {index: 246, big_category_name:  "製造業界の会社", name: "防災・防犯機器業界の会社", link: "https://baseconnect.in/companies/category/3eba287a-d5e2-4b1f-b1b7-bc679689e296", quantity: 10009},
            {index: 247, big_category_name:  "製造業界の会社", name: "金属製品製造業界の会社", link: "https://baseconnect.in/companies/category/6c358c96-c329-479f-adf7-256bcdff9a94", quantity: 6388},
            {index: 248, big_category_name:  "製造業界の会社", name: "鉄鋼製造業界の会社", link: "https://baseconnect.in/companies/category/cd1c641f-5a08-4e3e-8a15-f6f0e97096c2", quantity: 4311},
            {index: 249, big_category_name:  "製造業界の会社", name: "紙類包装資材製造業界の会社", link: "https://baseconnect.in/companies/category/0c8ce163-da83-4dda-ab43-29dd232247aa", quantity: 3739},
            {index: 250, big_category_name:  "製造業界の会社", name: "プラスチック包装資材製造業界の会社", link: "https://baseconnect.in/companies/category/2c7258f8-093f-4cf7-8bf0-49264c7afd28", quantity: 2532},
            {index: 251, big_category_name:  "製造業界の会社", name: "製紙・パルプ製造業界の会社", link: "https://baseconnect.in/companies/category/72cb2fd2-4662-41f4-a23b-72b7e9c0003a", quantity: 1379},
            {index: 252, big_category_name:  "製造業界の会社", name: "ガラス製造業界の会社", link: "https://baseconnect.in/companies/category/2064f7cd-adce-48a4-9c46-6786c5c2253e", quantity: 1095},
            {index: 253, big_category_name:  "製造業界の会社", name: "パイプ・バルブ製造業界の会社", link: "https://baseconnect.in/companies/category/a6e98fc2-a227-4f17-8c85-7b4659a10547", quantity: 967},
            {index: 254, big_category_name:  "製造業界の会社", name: "電線・ケーブル製造業界の会社", link: "https://baseconnect.in/companies/category/78c0a73d-5896-4b6a-87f8-d0b1bfded140", quantity: 870},
            {index: 255, big_category_name:  "製造業界の会社", name: "ステンレス製品製造業界の会社", link: "https://baseconnect.in/companies/category/f120d33b-d21b-4a28-861c-582081fdfa85", quantity: 867},
            {index: 256, big_category_name:  "製造業界の会社", name: "皮革製造業界の会社", link: "https://baseconnect.in/companies/category/07f42a27-5c80-466c-a94a-4f92590253b8", quantity: 781},
            {index: 257, big_category_name:  "製造業界の会社", name: "非鉄金属製造業界の会社", link: "https://baseconnect.in/companies/category/c2785869-0d96-4864-8353-b54405ead5c4", quantity: 721},
            {index: 258, big_category_name:  "製造業界の会社", name: "繊維製造業界の会社", link: "https://baseconnect.in/companies/category/576bab14-1dfb-481e-ae21-bbc1a28260c3", quantity: 717},
            {index: 259, big_category_name:  "製造業界の会社", name: "作業関連用品製造業界の会社", link: "https://baseconnect.in/companies/category/835fc441-e586-4641-9697-247256e519ee", quantity: 602},
            {index: 260, big_category_name:  "製造業界の会社", name: "電池製造業界の会社", link: "https://baseconnect.in/companies/category/20b6a683-ef1e-4bd9-9075-3f206b165ac9", quantity: 290},
            {index: 261, big_category_name:  "コンサルティング業界の会社", name: "土木・建築コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/d7542150-3534-4d03-be91-719197df301b", quantity: 14510},
            {index: 262, big_category_name:  "コンサルティング業界の会社", name: "不動産コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/17166d02-2408-4944-a0ef-f29d96025e37", quantity: 13002},
            {index: 263, big_category_name:  "コンサルティング業界の会社", name: "ITコンサルティング業界の会社 ", link: "https://baseconnect.in/companies/category/23995583-1bb1-4c09-bf4f-80dd88f1888c", quantity: 11744},
            {index: 264, big_category_name:  "コンサルティング業界の会社", name: "経営コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/7b6720db-86d8-43eb-94f9-c2405755977e", quantity: 11730},
            {index: 265, big_category_name:  "コンサルティング業界の会社", name: "その他コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/f24ca8bb-79d9-4f13-96eb-db011061543f", quantity: 9843},
            {index: 266, big_category_name:  "コンサルティング業界の会社", name: "販売促進コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/43bf248f-c04f-4bc0-861f-ff29374cba69", quantity: 5371},
            {index: 267, big_category_name:  "コンサルティング業界の会社", name: "Webマーケティング業界の会社", link: "https://baseconnect.in/companies/category/c6b6da03-db2e-49c0-a5b3-a3923339d4d8", quantity: 4228},
            {index: 268, big_category_name:  "コンサルティング業界の会社", name: "組織・人事コンサルティング業界", link: "https://baseconnect.in/companies/category/30d297ad-072a-4bea-a77b-23c3e5b242c8", quantity: 2576},
            {index: 269, big_category_name:  "コンサルティング業界の会社", name: "医療系コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/2d99b09a-a1d4-4a35-b31c-262b72ba3614", quantity: 2009},
            {index: 270, big_category_name:  "コンサルティング業界の会社", name: "資産運用コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/8d8a5123-e79a-45e1-a178-5ca123bcc944", quantity: 1692},
            {index: 271, big_category_name:  "コンサルティング業界の会社", name: "起業コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/6b2096db-4253-4efc-8b9e-6b817765d596", quantity: 1529},
            {index: 272, big_category_name:  "コンサルティング業界の会社", name: "財務・監査コンサルティング業界", link: "https://baseconnect.in/companies/category/93e555a7-088a-4ac1-ad4d-ec72e8485af1", quantity: 1177},
            {index: 273, big_category_name:  "コンサルティング業界の会社", name: "広告運用コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/4bf00329-0ad6-4d3a-b7d0-b4c6c4c1d02d", quantity: 1041},
            {index: 274, big_category_name:  "コンサルティング業界の会社", name: "コスト削減コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/a1243378-08eb-44c4-a8a2-78e8d4cc7471", quantity: 1035},
            {index: 275, big_category_name:  "コンサルティング業界の会社", name: "飲食店コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/6378aa08-cbd2-4ac3-a472-30e3ecfaab67", quantity: 927},
            {index: 276, big_category_name:  "コンサルティング業界の会社", name: "製造業コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/65dc62ac-cb92-41b9-be06-e0771ca2a77d", quantity: 723},
            {index: 277, big_category_name:  "コンサルティング業界の会社", name: "総合コンサルティング業界の会社", link: "https://baseconnect.in/companies/category/2b9c59de-018e-44d9-9749-0085ea84dbf8", quantity: 239},
            {index: 278, big_category_name:  "食品業界の会社", name: "酒・ワイン業界の会社", link: "https://baseconnect.in/companies/category/4a9f27e1-61d7-426b-8e30-49aadf1b7535", quantity: 7988},
            {index: 279, big_category_name:  "食品業界の会社", name: "農業界の会社", link: "https://baseconnect.in/companies/category/6eb8795f-3ad2-48dd-a91f-200f97752f2d", quantity: 7151},
            {index: 280, big_category_name:  "食品業界の会社", name: "水産業界の会社", link: "https://baseconnect.in/companies/category/75fb2c63-8eb6-4876-b3c2-f3f2c9ab8edb", quantity: 6446},
            {index: 281, big_category_name:  "食品業界の会社", name: "健康食品業界の会社", link: "https://baseconnect.in/companies/category/e58f4a7c-2ef5-495d-bfc2-7107ffc2a3bb", quantity: 6314},
            {index: 282, big_category_name:  "食品業界の会社", name: "その他食品業界の会社", link: "https://baseconnect.in/companies/category/7391c522-dc0f-4adf-9b5a-6910f174c676", quantity: 4649},
            {index: 283, big_category_name:  "食品業界の会社", name: "和菓子業界の会社", link: "https://baseconnect.in/companies/category/ab876212-0524-44a1-b983-9741058aef14", quantity: 4421},
            {index: 284, big_category_name:  "食品業界の会社", name: "食肉業界の会社", link: "https://baseconnect.in/companies/category/6959fedc-e934-421e-a762-9eacfdd29dc5", quantity: 4050},
            {index: 285, big_category_name:  "食品業界の会社", name: "洋菓子業界の会社", link: "https://baseconnect.in/companies/category/f1f44c47-fff4-4cea-b9b6-d1eb17a69efd", quantity: 3583},
            {index: 286, big_category_name:  "食品業界の会社", name: "漬物・煮物・大豆製造業界の会社", link: "https://baseconnect.in/companies/category/4c57f50c-de66-44bc-9a04-5cc7ceda3150", quantity: 2926},
            {index: 287, big_category_name:  "食品業界の会社", name: "調味料製造業界の会社", link: "https://baseconnect.in/companies/category/f77e3d0f-1dff-476e-bb74-202dca923ac6", quantity: 2817},
            {index: 288, big_category_name:  "食品業界の会社", name: "飲料製造業界の会社", link: "https://baseconnect.in/companies/category/05c56033-ef28-4f47-b510-e8b05fd02377", quantity: 2640},
            {index: 289, big_category_name:  "食品業界の会社", name: "米飯・惣菜製造業界の会社", link: "https://baseconnect.in/companies/category/0d63e119-50ae-4a00-9779-804cc47a6294", quantity: 2211},
            {index: 290, big_category_name:  "食品業界の会社", name: "その他菓子業界の会社", link: "https://baseconnect.in/companies/category/ad7c0ca3-8117-4341-bdb0-50b87f3394c8", quantity: 2112},
            {index: 291, big_category_name:  "食品業界の会社", name: "麺類製造業界の会社", link: "https://baseconnect.in/companies/category/7a8278e3-3065-483a-8a5d-58f7d752c70d", quantity: 1863},
            {index: 292, big_category_name:  "食品業界の会社", name: "パン業界の会社", link: "https://baseconnect.in/companies/category/4a687639-fd6e-4d14-ac7f-7bf1a3117737", quantity: 1837},
            {index: 293, big_category_name:  "食品業界の会社", name: "缶詰・レトルト・冷凍食品製造業界の会社", link: "https://baseconnect.in/companies/category/db5b52b2-c7ba-41a5-ad6d-e0bc8279697d", quantity: 1699},
            {index: 294, big_category_name:  "食品業界の会社", name: "乳製品業界の会社", link: "https://baseconnect.in/companies/category/045407be-b7a7-4a12-a76a-32201058fa72", quantity: 907},
            {index: 295, big_category_name:  "食品業界の会社", name: "製粉・食用油製造業界の会社", link: "https://baseconnect.in/companies/category/9658cbbf-eeda-4feb-b212-06d38031f05e", quantity: 613},
            {index: 296, big_category_name:  "食品業界の会社", name: "コーヒー製造業界の会社", link: "https://baseconnect.in/companies/category/5cd96d4c-9fa7-44a9-8353-aaab8236f191", quantity: 571},
            {index: 297, big_category_name:  "運輸・物流業界の会社", name: "一般貨物輸送業界の会社", link: "https://baseconnect.in/companies/category/4b7deb80-1888-4729-94f1-53e5ede1541e", quantity: 19268},
            {index: 298, big_category_name:  "運輸・物流業界の会社", name: "倉庫運営業界の会社", link: "https://baseconnect.in/companies/category/f0428ec8-ae50-4c8f-966b-24c055c91b79", quantity: 9032},
            {index: 299, big_category_name:  "運輸・物流業界の会社", name: "重量物輸送業界の会社", link: "https://baseconnect.in/companies/category/ffc5cf05-fc93-4428-a168-c8eb84f964ad", quantity: 8417},
            {index: 300, big_category_name:  "運輸・物流業界の会社", name: "タクシー業界の会社", link: "https://baseconnect.in/companies/category/cc2119fa-46f6-4509-94ed-9382d5aa00e1", quantity: 5193},
            {index: 301, big_category_name:  "運輸・物流業界の会社", name: "その他運輸・物流業界の会社", link: "https://baseconnect.in/companies/category/4a86cb7a-2509-46b7-ba52-3939e7e3f59f", quantity: 4236},
            {index: 302, big_category_name:  "運輸・物流業界の会社", name: "引っ越し業界の会社", link: "https://baseconnect.in/companies/category/4fb2e496-89e8-4303-aea6-3cbe82534ca1", quantity: 3089},
            {index: 303, big_category_name:  "運輸・物流業界の会社", name: "冷凍冷蔵車運行業界の会社", link: "https://baseconnect.in/companies/category/cc9ab8c3-141a-4301-b118-6877d233d57c", quantity: 2938},
            {index: 304, big_category_name:  "運輸・物流業界の会社", name: "バス業界の会社", link: "https://baseconnect.in/companies/category/a34595d3-454a-43a2-ad1d-e9e479647b93", quantity: 2778},
            {index: 305, big_category_name:  "運輸・物流業界の会社", name: "海運業界の会社", link: "https://baseconnect.in/companies/category/f7456a92-dad1-4d44-9024-0a5444ab2961", quantity: 2501},
            {index: 306, big_category_name:  "運輸・物流業界の会社", name: "機械輸送業界の会社", link: "https://baseconnect.in/companies/category/0d338d91-dce3-41ba-b52f-d21751404998", quantity: 2302},
            {index: 307, big_category_name:  "運輸・物流業界の会社", name: "港湾作業業界の会社", link: "https://baseconnect.in/companies/category/aea604b8-ece3-44ee-bb36-dcda9f823688", quantity: 815},
            {index: 308, big_category_name:  "運輸・物流業界の会社", name: "空運業界の会社", link: "https://baseconnect.in/companies/category/d0f310f0-45f7-4ebf-8e69-05bc1f7921e6", quantity: 546},
            {index: 309, big_category_name:  "運輸・物流業界の会社", name: "鉄道業界の会社", link: "https://baseconnect.in/companies/category/f4907501-605a-4aa2-a067-c98a7c344d56", quantity: 235},
            {index: 310, big_category_name:  "IT業界の会社", name: "システム受託開発業界の会社", link: "https://baseconnect.in/companies/category/a2b5e24f-c628-44e5-a341-b6e4a6e4f0e3", quantity: 18271},
            {index: 311, big_category_name:  "IT業界の会社", name: "システム開発業界の会社", link: "https://baseconnect.in/companies/category/377d61f9-f6d3-4474-a6aa-4f14e3fd9b17", quantity: 16383},
            {index: 312, big_category_name:  "IT業界の会社", name: "Webサービス・アプリ運営業界の会社", link: "https://baseconnect.in/companies/category/b1d5c1e6-7cc5-41c4-9552-28530d2c9e9c", quantity: 9101},
            {index: 313, big_category_name:  "IT業界の会社", name: "ITインフラ業界の会社", link: "https://baseconnect.in/companies/category/a14a8e55-2735-4844-841e-73fef92a3596", quantity: 5751},
            {index: 314, big_category_name:  "IT業界の会社", name: "ソフトウェア専門商社業界の会社", link: "https://baseconnect.in/companies/category/699e937a-ca46-4b5b-be76-80b6d4a41c5d", quantity: 2001},
            {index: 315, big_category_name:  "IT業界の会社", name: "デジタルコンテンツ業界の会社", link: "https://baseconnect.in/companies/category/37b7583c-431d-408d-ac66-fd1a18f84c41", quantity: 1829},
            {index: 316, big_category_name:  "IT業界の会社", name: "クラウド・フィンテック業界の会社", link: "https://baseconnect.in/companies/category/578d6793-48f8-4776-906f-756a0b42f195", quantity: 1314},
            {index: 317, big_category_name:  "IT業界の会社", name: "情報セキュリティサービス業界の会社", link: "https://baseconnect.in/companies/category/c26b945f-0529-4ec1-a43f-dc9750e7fbdd", quantity: 872},
            {index: 318, big_category_name:  "IT業界の会社", name: "その他IT業界の会社", link: "https://baseconnect.in/companies/category/9b4a37c1-d034-4a37-a448-c852cbbb0f40", quantity: 711},
            {index: 319, big_category_name:  "医療・福祉業界の会社", name: "高齢者向け福祉業界の会社", link: "https://baseconnect.in/companies/category/03880de9-628c-48d3-b583-f0bc7fb9f2bc", quantity: 16429},
            {index: 320, big_category_name:  "医療・福祉業界の会社", name: "障害者福祉業界の会社", link: "https://baseconnect.in/companies/category/eef52007-738c-46be-88f3-e943e6dc61ce", quantity: 6474},
            {index: 321, big_category_name:  "医療・福祉業界の会社", name: "調剤薬局業界の会社", link: "https://baseconnect.in/companies/category/6cb37e06-0ebc-436f-a928-3f174cf76669", quantity: 6419},
            {index: 322, big_category_name:  "医療・福祉業界の会社", name: "介護用品・家庭用医療機器業界の会社", link: "https://baseconnect.in/companies/category/485ab16b-28f9-4966-a82c-78bf79b55145", quantity: 6056},
            {index: 323, big_category_name:  "医療・福祉業界の会社", name: "高齢者住宅業界の会社", link: "https://baseconnect.in/companies/category/aac76c76-663f-4ea5-aef0-51a24767b3c2", quantity: 5422},
            {index: 324, big_category_name:  "医療・福祉業界の会社", name: "医療機器・実験機器メーカー業界の会社", link: "https://baseconnect.in/companies/category/e8b4fb2e-8cf9-473d-be34-3f729e65fdf3", quantity: 3417},
            {index: 325, big_category_name:  "医療・福祉業界の会社", name: "医療・療養施設(病院など)業界の会社", link: "https://baseconnect.in/companies/category/7b5ce46d-ae6c-401b-8e27-f21892dc7df8", quantity: 3008},
            {index: 326, big_category_name:  "医療・福祉業界の会社", name: "製薬業界の会社", link: "https://baseconnect.in/companies/category/e3746deb-32c4-4b0b-8074-d20957c5eed7", quantity: 1329},
            {index: 327, big_category_name:  "医療・福祉業界の会社", name: "児童福祉業界の会社", link: "https://baseconnect.in/companies/category/102c090d-f82b-4f72-91d9-c87a886cb672", quantity: 1146},
            {index: 328, big_category_name:  "医療・福祉業界の会社", name: "その他医療・福祉業界の会社", link: "https://baseconnect.in/companies/category/7019455d-f35a-4abb-aabc-7d0bd2fdaf77", quantity: 660},
            {index: 329, big_category_name:  "広告業界の会社", name: "紙媒体印刷業界の会社", link: "https://baseconnect.in/companies/category/bcd72229-e057-41a6-857d-622829b7e069", quantity: 13454},
            {index: 330, big_category_name:  "広告業界の会社", name: "看板業界の会社", link: "https://baseconnect.in/companies/category/d483e076-1e86-4f64-bac0-e79cb0310226", quantity: 7456},
            {index: 331, big_category_name:  "広告業界の会社", name: "その他印刷業界の会社", link: "https://baseconnect.in/companies/category/d9688902-408e-4e9b-bd30-70c5e1ab7275", quantity: 6638},
            {index: 332, big_category_name:  "広告業界の会社", name: "広告代理店業界の会社", link: "https://baseconnect.in/companies/category/18a492fd-a6a5-423e-b70f-594046664d74", quantity: 5756},
            {index: 333, big_category_name:  "広告業界の会社", name: "インターネット広告代理店業界の会社", link: "https://baseconnect.in/companies/category/56705ce0-0fe4-40cb-9659-68f5eaa45d27", quantity: 2696},
            {index: 334, big_category_name:  "広告業界の会社", name: "企業展示会・販促イベント業界の会社", link: "https://baseconnect.in/companies/category/29126a91-426e-49d1-8f6a-f0d2629fb9e4", quantity: 1911},
            {index: 335, big_category_name:  "広告業界の会社", name: "その他広告業界の会社", link: "https://baseconnect.in/companies/category/c3047863-48ad-4265-a601-18e3762d4dee", quantity: 998},
            {index: 336, big_category_name:  "外食業界の会社", name: "和食・大衆料理業界の会社", link: "https://baseconnect.in/companies/category/be76e0fc-970e-487d-8941-8db993215e4c", quantity: 6370},
            {index: 337, big_category_name:  "外食業界の会社", name: "カフェ・喫茶店業界の会社", link: "https://baseconnect.in/companies/category/195dcf25-df65-4a4a-b8e7-54f4038a919e", quantity: 4525},
            {index: 338, big_category_name:  "外食業界の会社", name: "洋食・西洋料理業界の会社", link: "https://baseconnect.in/companies/category/397ee29e-3665-4c56-b946-b0caa1bf9a21", quantity: 4475},
            {index: 339, big_category_name:  "外食業界の会社", name: "居酒屋・バー業界の会社", link: "https://baseconnect.in/companies/category/eb129a1e-d8d2-4bf6-97b4-69cfb6f034ff", quantity: 4418},
            {index: 340, big_category_name:  "外食業界の会社", name: "中食（デリバリー）業界の会社", link: "https://baseconnect.in/companies/category/1883ff06-f22a-4ec4-bbbd-b9944a257806", quantity: 4103},
            {index: 341, big_category_name:  "外食業界の会社", name: "麺類店業界の会社", link: "https://baseconnect.in/companies/category/ab364fed-89e4-40df-9900-bb5de1c48fb7", quantity: 2854},
            {index: 342, big_category_name:  "外食業界の会社", name: "肉料理店業界の会社", link: "https://baseconnect.in/companies/category/618add56-5cb3-4408-b7cd-a1274db6c4cf", quantity: 1899},
            {index: 343, big_category_name:  "外食業界の会社", name: "その他外食業界の会社", link: "https://baseconnect.in/companies/category/7ce7aa07-7cfa-4e6f-aea7-f348967f0a5b", quantity: 1878},
            {index: 344, big_category_name:  "外食業界の会社", name: "アジア・エスニック料理業界の会社", link: "https://baseconnect.in/companies/category/39db5bc6-ef3a-425d-9b53-30c5b5c7cf7f", quantity: 1706},
            {index: 345, big_category_name:  "外食業界の会社", name: "給食・食堂業界の会社", link: "https://baseconnect.in/companies/category/3d0f7227-266f-4ede-b33e-3a9d610f9763", quantity: 1704},
            {index: 346, big_category_name:  "外食業界の会社", name: "寿司屋業界の会社", link: "https://baseconnect.in/companies/category/6eff82ad-e7d1-47b5-a696-369e156f36cb", quantity: 1131},
            {index: 347, big_category_name:  "外食業界の会社", name: "ファーストフード業界の会社", link: "https://baseconnect.in/companies/category/38489256-2795-4322-945d-04c8cc7c42cd", quantity: 372},
            {index: 348, big_category_name:  "外食業界の会社", name: "ファミリーレストラン業界の会社", link: "https://baseconnect.in/companies/category/d033f47f-cf1b-4772-b0bd-9e59c4b4a315", quantity: 58},
            {index: 349, big_category_name:  "金融業界の会社", name: "保険代理店業界の会社", link: "https://baseconnect.in/companies/category/fc1c1c84-05e3-45dc-b5d9-9bdd6071f181", quantity: 16233},
            {index: 350, big_category_name:  "金融業界の会社", name: "投資業界の会社", link: "https://baseconnect.in/companies/category/307c9f2e-d339-4166-82c1-076abd98a3ef", quantity: 1457},
            {index: 351, big_category_name:  "金融業界の会社", name: "保険業界の会社", link: "https://baseconnect.in/companies/category/b644435d-2cb4-4821-b360-14948e7779bb", quantity: 1404},
            {index: 352, big_category_name:  "金融業界の会社", name: "貸金業界の会社", link: "https://baseconnect.in/companies/category/cf3d0f47-630c-4cf3-bb88-54a98a5c222d", quantity: 869},
            {index: 353, big_category_name:  "金融業界の会社", name: "その他金融関連サービス業界の会社", link: "https://baseconnect.in/companies/category/3dd58786-04c5-41a9-aa5c-8738d320f7fc", quantity: 734},
            {index: 354, big_category_name:  "金融業界の会社", name: "クレジット・信販・決済代行業界の会社", link: "https://baseconnect.in/companies/category/731ae735-8c11-410e-9f41-c6adfc11ba11", quantity: 525},
            {index: 355, big_category_name:  "金融業界の会社", name: "証券業界の会社", link: "https://baseconnect.in/companies/category/0a5b6d3c-1085-489b-b937-eda05fce8878", quantity: 483},
            {index: 356, big_category_name:  "金融業界の会社", name: "事業者金融業界の会社", link: "https://baseconnect.in/companies/category/f994c9e9-33c2-4094-b95b-e795d73f7304", quantity: 324},
            {index: 357, big_category_name:  "金融業界の会社", name: "銀行・信用金庫・信用組合業界の会社", link: "https://baseconnect.in/companies/category/e1275817-5895-4e1a-97c5-b2dcde6f4688", quantity: 236},
            {index: 358, big_category_name:  "金融業界の会社", name: "ネット証券業界の会社", link: "https://baseconnect.in/companies/category/ec77db74-0290-46a0-92fa-324c9d4cf629", quantity: 76},
            {index: 359, big_category_name:  "教育業界", name: "その他スクール業界の会社", link: "https://baseconnect.in/companies/category/f54559b8-fdbb-4bd8-93df-f92b50443518", quantity: 8386},
            {index: 360, big_category_name:  "教育業界", name: "資格取得・通信教育業界の会社", link: "https://baseconnect.in/companies/category/f20df487-cf37-4f72-9c91-d04fc597f8e5", quantity: 2359},
            {index: 361, big_category_name:  "教育業界", name: "塾・受験予備校業界の会社", link: "https://baseconnect.in/companies/category/8ed48d2f-7312-4fb7-add9-a49dd45dcc40", quantity: 2094},
            {index: 362, big_category_name:  "教育業界", name: "児童保育業界の会社", link: "https://baseconnect.in/companies/category/93011ee2-e49b-4990-be21-36f02a0a6473", quantity: 1832},
            {index: 363, big_category_name:  "教育業界", name: "教材業界の会社", link: "https://baseconnect.in/companies/category/843baabc-fd24-4f5e-b79f-14f5948f62fc", quantity: 1738},
            {index: 364, big_category_name:  "教育業界", name: "語学学習スクール業界の会社", link: "https://baseconnect.in/companies/category/2e251650-8d52-4625-8999-f7aa5326bde5", quantity: 1472},
            {index: 365, big_category_name:  "教育業界", name: "IT教育業界の会社", link: "https://baseconnect.in/companies/category/df97ba67-1e1e-4578-931e-9422c18a1953", quantity: 1060},
            {index: 366, big_category_name:  "教育業界", name: "学校業界の会社", link: "https://baseconnect.in/companies/category/edd1551f-0ff0-415a-95b4-24635f39de65", quantity: 176},
            {index: 367, big_category_name:  "教育業界", name: "その他教育業界", link: "https://baseconnect.in/companies/category/19850b4b-1ebd-4008-a897-89031954bc62", quantity: 157},
            {index: 368, big_category_name:  "電気製品業界の会社", name: "家電業界の会社", link: "https://baseconnect.in/companies/category/00c18b9f-ca60-4cd5-9afa-7a110a502b78", quantity: 6511},
            {index: 369, big_category_name:  "電気製品業界の会社", name: "照明器具業界の会社", link: "https://baseconnect.in/companies/category/bc6c5f5a-203d-4c54-adc8-6447e659f521", quantity: 2486},
            {index: 370, big_category_name:  "電気製品業界の会社", name: "その他電気製品製造業界の会社", link: "https://baseconnect.in/companies/category/42a5ada7-c773-4011-a1f9-3266ed5f06a2", quantity: 1324},
            {index: 371, big_category_name:  "電気製品業界の会社", name: "音響・映像機器業界の会社", link: "https://baseconnect.in/companies/category/a8c807e7-6784-4d86-9de5-a4a4fecdb297", quantity: 1029},
            {index: 372, big_category_name:  "専門サービス業界の会社", name: "翻訳・通訳業界の会社", link: "https://baseconnect.in/companies/category/a69f5cdc-d04c-4acf-8888-049899c18338", quantity: 2019},
            {index: 373, big_category_name:  "専門サービス業界の会社", name: "専門事務所業界の会社", link: "https://baseconnect.in/companies/category/a1c58cab-a3ca-4895-9fd5-f9315537bf44", quantity: 1615},
            {index: 374, big_category_name:  "通信機器業界の会社", name: "パソコン販売・修理業界の会社", link: "https://baseconnect.in/companies/category/5278db7d-d2de-4295-b9ca-e07e620a80b3", quantity: 1844},
            {index: 375, big_category_name:  "通信機器業界の会社", name: "その他通信機器業界の会社", link: "https://baseconnect.in/companies/category/cdcbf8f4-af10-49d9-8a80-1a0b6af7ae47", quantity: 691},
            {index: 376, big_category_name:  "通信機器業界の会社", name: "パソコン・スマホ周辺機器製造業界の会社", link: "https://baseconnect.in/companies/category/a8c4b0ce-5b3c-4f97-9aee-35e0ee99db84", quantity: 635},
            {index: 377, big_category_name:  "通信機器業界の会社", name: "パソコン製造業界の会社", link: "https://baseconnect.in/companies/category/a7eea2c4-82af-4078-9bd5-55785c654885", quantity: 169},
            {index: 378, big_category_name:  "通信機器業界の会社", name: "スマホ・タブレット製造・修理業界の会社", link: "https://baseconnect.in/companies/category/e563d6fc-88c1-4f61-af13-ae2509ccca3c", quantity: 143},
            {index: 379, big_category_name:  "通信機器業界の会社", name: "電話機製造業界の会社", link: "https://baseconnect.in/companies/category/348f9ffb-9f27-4449-9f70-80a4f03ff88b", quantity: 128},
            {index: 380, big_category_name:  "その他業界", name: "その他業界の会社", link: "https://baseconnect.in/companies/category/ea38f117-86d5-4c8d-adee-b301b3813f7e", quantity: 355 }
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
