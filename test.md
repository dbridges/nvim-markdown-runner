# Markdown Runner Demo

Test empty fail.
```
```

```
echo "Hello from your Shell"
echo "Still saying hi"
```

```javascript <!-- Test the Comment -->
console.log("Hello from Javascript (Node)")
```

```
curl -s http://example.com
```

```js
console.log("Hello from Javascript (Node)")
```

```go
resp, err := http.Get("http://example.com/")
if err != nil {
	// handle error
}
defer resp.Body.Close()
body, err := ioutil.ReadAll(resp.Body)
fmt.Println(string(body))
```

```python
print("Hello from Python")
```

```ruby
puts "Hello from Ruby"
```

```swift
print("Hello from Swift")
```

```vim
echo "Hello from Vim"
```

```api.json
POST localhost:5000/people
X-User: Admin

{
  "name": "New Person"
}
```

```api.json.info
GET localhost:5000/people
X-User: Admin
q=New
```

```api.json.info
GET localhost:5000/test-auth
-u user:pass
```
