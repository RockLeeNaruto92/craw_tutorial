Để lấy các link profile của member trong 1 group thì làm như sau:

### 1. Truy cập vào trang members của group đó, xác định groupid

- Có thể thao tác trực tiếp trên màn hình hoặc là truy cập vào đường link `https://www.facebook.com/groups/{group_id}/members`.
- Click vào 1 member bất kì. Nó sẽ có link như thế này: `https://www.facebook.com/groups/368698476630471/user/100066637926277`
- Thì cái số sau `groups/`, trước `/user` chính là cái group_id.
- Trong trường hợp trên thì group_id là: `368698476630471`

### 2. Quay trở lại trang members của group đó.

### 3. Bật javascript console của browser lên

Nếu chưa biết cách bật thì xem tại link này: https://openplanning.net/12409/javascript-console

### 4. Paste đoạn code sau vào javascript console

```javascript
var doScroll = function(count, max_time){
  if (count >= max_time) {
    console.log("Stop scroll");
    return
  };

  window.setTimeout(function(){
    window.scrollTo(0,document.body.scrollHeight);
    count += 1;
    console.log("DoScroll: " + count);
    doScroll(count, max_time);
  }, 1000);
}

doScroll(0, 100);
```

★ Sau khi cái đoạn trên chạy xong, cái log cuối cùng nó xuất ra sẽ là `Stop scroll`. Nếu thấy chữ `Stop scroll` sang bước tiếp theo

### 5. Sửa đoạn code lấy data sau đây.

- Bật notepad lên
- Copy đoạn này ra notepad
- Thay cái `{group_id}` bằng cái group_id lấy được ở STEP 1
- Copy đoạn code vừa sửa, paste vào javascript console của browser

```javascript

group_id = "{group_id}" // Thay cái này bằng group_id lấy được ở Step 1
users = document.querySelectorAll("a[href*='/groups/" + group_id + "/user/'")

links = [];

for (var i = 0; i < users.length; i++) {
    if (!users[i].href.includes("friends_mutual")) {
        links.push(users[i].href);
    }
    links.push(users[i].href);
}

function onlyUnique(value, index, self) {
    return self.indexOf(value) === index;
}

var uniqueLinks = links.filter(onlyUnique);

console.log(uniqueLinks.length);

csvContent = "data:text/csv;charset=utf-8,";

uniqueLinks.forEach(function (rowArray) {
    let row = rowArray;
    csvContent += row + "\r\n";
});

var encodedUri = encodeURI(csvContent);
window.open(encodedUri);
```

### 7. Save file dưới dạng csv và upload lên drive

- Lưu tên file thành tên group cho dễ nhớ.
- Upload lên Folder driver: https://drive.google.com/drive/u/0/folders/1JvL-QFKn8Q0lLnNTz0P2DrZQyQso0h_p
