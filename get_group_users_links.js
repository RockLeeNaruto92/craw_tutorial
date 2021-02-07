users = document.querySelectorAll("a[href*='/groups/463289037358737/user/'")

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