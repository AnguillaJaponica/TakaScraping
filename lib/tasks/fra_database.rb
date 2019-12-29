require 'capybara'
require 'webdrivers'
require 'selenium-webdriver'

class AquaticOrganisms
  attr_reader :browser_session

  SCRAPING_TARGET = 'https://www.fishery-terminology.jp/glossary_browse1.php'

  def start(capybara_client_url)
    capybara_init(capybara_client_url)
    yield(self)
  ensure
    close_browser_session
  end

  # Capybaraの初期設定
  # @param [capybara_client_url] capybaraでwebブラウザを起動させる先のurl
  # @return [Capybara::Session] capybaraのブラウザ（chrome）セッション
  def capybara_init(capybara_client_url)
    # ブラウザ初期設定
    Capybara.register_driver :selenium_chrome do |app|
      Capybara::Selenium::Driver.new(app,
                                     browser: :chrome,
                                     desired_capabilities: Selenium::WebDriver::Remote::Capabilities.chrome(
                                         chrome_options: {
                                             args: %w(headless no-sandbox disable-gpu window-size=1280,800),
                                         },
                                         ),
                                     url: capybara_client_url
      )
    end
    Capybara.javascript_driver = :selenium_chrome
    # 画面外の非表示部分の値を取得する設定
    Capybara.ignore_hidden_elements = false
    @browser_session =  Capybara::Session.new(:selenium_chrome)
  end

  # netDoAにある店舗の売上情報を取得する
  # @param [Date] target_date データ取得の対象日
  # @return [Hash] { 店舗名: { 項目名: string, 項目名: { 小項目名: string } } }
  def get_all_sales(target_date)
    sales_with_item_name = {}
    # iframe内の要素を取得する
    browser_session.within_frame browser_session.find('iframe') do
      return nil unless browser_session.has_css?('#col_fixed_table')
      # 販売分析画面の売上項目名を取得
      sales_item_names = get_sales_item_names

      # 店舗ごとの売上の数字だけを取得
      sales_each_shop = get_sales_each_shop

      # 店舗ごとに売上の数字と売上項目を紐付ける
      sales_each_shop.each do |shop_name, sales|
        sales_with_item_name[shop_name] = make_sales_with_items(sales_item_names, sales)
      end
    end
    sales_with_item_name
  end

  # 販売分析画面の売上項目名を取得
  # @return [Hash] { 売上項目名: nil, 売上項目名: { 売上小項目名: nil } }
  def get_sales_item_names
    table_rows = browser_session.first(:css, '#table').find_all(:css, 'tr')
    sales_item_names = {}
    rowspan = 0
    key = ''
    table_rows.each do |table_row|
      table_data = table_row.first('td')
      if table_data['rowspan']
        # rowspanが設定されていたらhashを追加して小項目を設定する
        rowspan = table_data['rowspan'].to_i - 1
        key = table_data.text
        sales_item_names[key] ||= {}
        # td[0]:大項目名 td[1]:小項目名
        small_key = table_row.find_all('td')[1].text
        sales_item_names[key][small_key] = nil
      elsif rowspan > 0
        rowspan -= 1
        sales_item_names[key][table_data.text] = nil
      else
        key = table_data.text
        sales_item_names[key] = nil
      end
    end
    sales_item_names
  end

  # 店舗ごとの売上の数字だけを取得
  # @return [Hash] { 店舗名: [販売データ] }
  def get_sales_each_shop
    # 店舗名取得
    netdoa_shop_names = browser_session.first(:css, '#row_fixed_table').first(:css, 'tr').find_all('td')
    sales_each_shop = {}
    netdoa_shop_names.each_with_index do |netdoa_shop_name, i|
      # shop_name "n：SBxxx"
      shop_name = netdoa_shop_name.text.split('：', 2).last
      # 店舗ごとの売上データ取得
      table_rows = browser_session.first(:css, '#detail_free_table').find_all(:css, 'tr')
      table_rows.each do |table_row|
        sales_each_shop[shop_name] ||= []
        value = table_row.find_all('td')[i].text
        sales_each_shop[shop_name].push(value)
      end
    end
    sales_each_shop
  end

  # 売上の数字と各項目を結合
  # @param [Hash] item_names 売上項目名 (項目: nil, 項目: { 小項目: nil })
  # @param [Array] sales 売上の数字 ([売上])
  # @return [Hash] { 項目名: string, 項目名: { 小項目名: string, 小項目名: string } }
  def make_sales_with_items(item_names, sales)
    sales_with_item_name = {}
    index = 0
    item_names.each do |item_name, item_value|
      if item_value.is_a?(Hash)
        # 小項目がある場合(項目名: { 小項目名: val1, 小項目名: val2 })
        item_value.each do |small_item_name, _|
          sales_with_item_name[item_name] ||= {}
          sales_with_item_name[item_name][small_item_name] = sales[index]
          index += 1
        end
      else
        sales_with_item_name[item_name] = sales[index]
        index += 1
      end
    end
    sales_with_item_name
  end

  # ブラウザを閉じる
  def close_browser_session
    browser_session.driver.quit
  end
end
