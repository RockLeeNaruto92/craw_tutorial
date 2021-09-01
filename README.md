### Setup trên window 10
#### Cài đặt chrome
#### Cài đặt chrome driver
  - Link: https://chromedriver.chromium.org/downloads
  - Các huynh đài nhớ tìm bản phù hợp với version chrome đang sử dụng
  - Nó là 1 file zip. Anh em extract ra cho vào ổ `C:\Program Files`.
  - Lấy đường dẫn với cái folder của nó cho vào PATH của window. https://www.architectryan.com/2018/03/17/add-to-the-path-on-windows-10/

#### Cài đặt ruby
- Download `rubyinstaller-devkit-2.7.2-1-x64.exe` bằng cách click vào [link này](https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-2.7.2-1/rubyinstaller-devkit-2.7.2-1-x64.exe)
- Thực hiện cài như bình thường. Các tỉ muội mà chưa biết cách cài vui lòng liên hệ với các huynh đệ bên cạnh để được support.

## Setup TorBrowser for windows

- https://www.torproject.org/download/
- Install

#### Download hoặc clone source code
- Download source code hoặc clone source code từ link này.
- Extract ra thành 1 folder. Gọi là folder `craw`.
- Các tỉ muội chưa biết cách download hay clone source code vui lòng liên hệ với các huynh đệ bên cạnh để được support.

#### Chạy

- Bật commandos
- cd vào trong folder `craw`. (Các huynh đài, tỉ muội nào chưa chạy lệnh trên commandos bao giờ thì vui lòng liên hệ với các huynh đệ bên cạnh để được hướng dẫn)
- Chạy các lệnh sau:

```
git checkout windows
gem install bundler -v 1.15.1
bundle install
```

- Chạy lệnh `ruby main.rb`. Đợi tầm vài giây, nếu mà nó tự động bật ra 1 cái tor browser mới và chrome mới và access vào trang https://baseconnect.in/ thì là ok.

### Implement craw 1 source mới
#### Require

- Cần có nguồn (cái này anh Nhật sẽ cung cấp)
- Developer cần hiểu được cấu trúc của html, css selector

#### Các bước cần xử lý

- Cần biết danh sách link detail của công ty trên cái source mà a Nhật cung cấp
  - Ví dụ: Trong baseconnect.in, dựa theo cấu trúc của trang thì để lấy được list link detail công ty như sau:
    - Vào trang home (https://baseconnect.in/)
    - Click vào 1 cái category bất kì trong list danh sách các category (tương đương với việc access vào link của 1 category https://baseconnect.in/companies/category/d861bd35-0830-4312-a872-443007e18e09)
    - Tại trang detail của category, có thể thấy 1 list danh sách các công ty -> ta có thể lấy được list danh sách các link detail của công ty trong page này bằng cách truy vấn theo css selector
    - Chú ý việc pagination của list các công ty trong category đó -> Thử thay đổi các parameter thích hợp trên url xem có ra kết quả mong muốn của mình hay không.

- Cần biết sẽ lấy được các thông tin gì trên link detail của công ty
  - Access vào link detail của công ty, về cơ bản thì cái gì hiển thị trên trang detail company thì mình sẽ lấy được các thông tin đó.
  - Cần research tầm chục link detail company để xem mình có thể lấy được những thông tin nào. (vì đôi lúc có công ty 1 ko có thông tin A và ko hiển thị nhưng công ty 2 thì có)
  - Về kĩ thuật thì truy vấn bằng css_selector để lấy được thông tin cần lấy.

- Code theo flow mà mình đã định nghĩa ở trên. Về cơ bản thì cái này nó không có cái quái gì cả.

#### Sửa code

- `objects/main_process.rb`

```
def call!
    Log.info "Start to craw data"
    driver = init_selenium_driver # Trong method này đã bật chrome, bật tor browser lên rồi

    # Implement chỗ này

    sleep 10

    quit_driver driver
    Log.info "End MainProcess#call!"
end
```
