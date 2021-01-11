require File.dirname(__FILE__) + "/log"
require File.dirname(__FILE__) + "/information"

class MainProcess
  class << self
    def call!
      Log.info "Start to craw data"

      # TODO:
      Log.info "Access to baseconnect.in"

      # TODO: Get all home_headlink + name
      Log.info "Get all home_headlink"

      home_headlinks = [
        {
          name: "小売業界の会社",
          link: "https://baseconnect.in" + "/companies/category/ba7eb4c7-40b7-466b-a2be-d0a8257d7974"
        }
      ]

      

      home_headlinks.each_with_index do |home_headlink, index|
          # TODO
          Log.info "------------------------------------------------------------"
          craw_for_a_category home_headlink, index
      end

      Log.info "End MainProcess#call!"
    end

    def craw_for_a_category home_headlink, index
        baseconnect_companies_list = []
        result = []

        (1..200).each do |page|
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

            # TODO
            Log.info "#{index + 1}:\t#{page}:\tWrite to spread sheet"

            write_to_spread_sheet home_headlink, result

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

    def write_to_spread_sheet home_headlink, result
        # TODO
        Log.info "Write to speadsheet"
    end
  end
end
