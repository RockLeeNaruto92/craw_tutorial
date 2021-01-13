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

- Sửa tí code như sau: 
  - Bật cái file `objects/main_process.rb`
  - Từ dòng 143 → 180 thấy có cái code như sau:
  ```
          [
            {
                name: "システム受託開発業界の会社",
                link: "https://baseconnect.in/companies/category/a2b5e24f-c628-44e5-a341-b6e4a6e4f0e3"
            },
            {
                name: "システム開発業界の会社",
                link: "https://baseconnect.in/companies/category/377d61f9-f6d3-4474-a6aa-4f14e3fd9b17"
            },
            {
                name: "Webサービス・アプリ運営業界の会社",
                link: "https://baseconnect.in/companies/category/b1d5c1e6-7cc5-41c4-9552-28530d2c9e9c"
            },
            {
                name: "シITインフラ業界の会社",
                link: "https://baseconnect.in/companies/category/a14a8e55-2735-4844-841e-73fef92a3596"
            },
            {
                name: "ソフトウェア専門商社業界の会社",
                link: "https://baseconnect.in/companies/category/699e937a-ca46-4b5b-be76-80b6d4a41c5d"
            },
            {
                name: "デジタルコンテンツ業界の会社",
                link: "https://baseconnect.in/companies/category/37b7583c-431d-408d-ac66-fd1a18f84c41"
            },
            {
                name: "クラウド・フィンテック業界の会社",
                link: "https://baseconnect.in/companies/category/578d6793-48f8-4776-906f-756a0b42f195"
            },
            {
                name: "情報セキュリティサービス業界の会社",
                link: "https://baseconnect.in/companies/category/c26b945f-0529-4ec1-a43f-dc9750e7fbdd"
            },
            {
                name: "その他IT業界の会社",
                link: "https://baseconnect.in/companies/category/9b4a37c1-d034-4a37-a448-c852cbbb0f40"
            }
        ]
  ```
  - Các huynh đài phân công như sau:
    - Huynh đài 1: Chạy nguyên phần `システム受託開発業界の会社` → Xóa cái đoạn từ dòng 31 -> 62
    - Huynh đài 2: Chạy nguyên phần `システム開発業界の会社` → Xóa 2 đoạn 27 -> 30 và 35 -> 62
    - Huynh đài 3: Chạy các phần còn lại → Xóa các dòng từ 27 -> 34

- Chạy lệnh `ruby main.rb`. Đợi tầm vài giây, nếu mà nó tự động bật ra 1 cái chrome mới và access vào trang https://baseconnect.in/ thì là ok.
