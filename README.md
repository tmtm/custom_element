# HTMLElement

ブラウザ上の ruby.wasm で HTMLElement を継承してクラスをつくるとカスタム要素を作成できる。

```html
<!DOCTYPE html>
<html>
  <script src="https://cdn.jsdelivr.net/npm/@ruby/3.3-wasm-wasi@2.6.2/dist/browser.script.iife.js">
  </script>
  <script src="https://cdn.jsdelivr.net/gh/tmtm/htmlelement@0.0.1/lib/htmlelement.rb"></script>
  <script type="text/ruby">
    class HogeHoge < HTMLElement
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

## License

MIT
