# CustomElement

ブラウザ上の ruby.wasm で CusotmElement を継承してクラスをつくるとカスタム要素を作成できる。

```html
<!DOCTYPE html>
<html>
  <script src="https://cdn.jsdelivr.net/npm/@ruby/3.3-wasm-wasi@2.6.2/dist/browser.script.iife.js"></script>
  <script type="text/ruby" src="https://cdn.jsdelivr.net/gh/tmtm/jsrb@v0.1.0/jsrb.rb"></script>
  <script type="text/ruby" src="https://cdn.jsdelivr.net/gh/tmtm/custom_element@v0.0.3/lib/custom_element.rb"></script>
  <script type="text/ruby">
    class HogeHoge < CustomElement
      def initialize
        self.text_content = 'hoge hoge'
        self.style.color = 'red'
      end
    end
  </script>

  <body>
    <hoge-hoge></hoge-hoge>
  </body>
</html>
```

この例は `<hoge-hoge>` 要素が作られたときに `HogeHoge#initialize` が実行される。

## License

MIT
