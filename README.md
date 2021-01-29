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

#### Download hoặc clone source code
- Download source code hoặc clone source code từ link này.
- Extract ra thành 1 folder. Gọi là folder `craw`.
- Các tỉ muội chưa biết cách download hay clone source code vui lòng liên hệ với các huynh đệ bên cạnh để được support.

#### Chạy

- Bật commandos
- cd vào trong folder `craw`. (Các huynh đài, tỉ muội nào chưa chạy lệnh trên commandos bao giờ thì vui lòng liên hệ với các huynh đệ bên cạnh để được hướng dẫn)
- Chạy các lệnh sau:

```
gem install bundler -v 1.15.1
bundle install
```

- Chạy lệnh `ruby main.rb`. Đợi tầm vài giây, nếu mà nó tự động bật ra 1 cái chrome mới và access vào trang https://baseconnect.in/ thì là ok.
