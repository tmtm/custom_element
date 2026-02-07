# base class for creating custom elements

JS.eval <<~JS
  RubyCustomElement = {
    objectIdMap: new WeakMap(),
    objectRubyIdMap: new WeakMap(),
    idObjectMap: new Map(),
    attributeChanged: new Map(),
    objectIdCounter: 0,
    objectId: function(object) {
      if (!this.objectIdMap.has(object)) {
        var id = ++this.objectIdCounter
        this.objectIdMap.set(object, id)
        this.idObjectMap.set(id, object)
      }
      return this.objectIdMap.get(object)
    },
    instanceOf: function(object, klass) {
      return object instanceof klass
    },
  }
JS

class << JSrb
  prepend Module.new {
    def convert(v)
      x = super
      if x.kind_of?(JSrb) && JS.global[:RubyCustomElement].instanceOf(x.js_object, JS.global[:HTMLElement])
        js_object_id = JS.global[:RubyCustomElement].objectId(x.js_object).to_i
        x = CustomElement.object_map[js_object_id] ||= x
      end
      x
    end
  }
end

class CustomElement
  def self.object_map
    @object_map ||= {}
  end

  def self.define(tag_name, element_class)
    JS.eval("customElements.define('#{tag_name}', #{element_class.name})")
  end

  def self.observed_attributes=(attrs)
    @observed_attributes = attrs
  end

  def self.observed_attributes
    @observed_attributes ||= []
  end

  def self.inherited(subclass)
    super
    subclass.define_singleton_method(:method_added){|_| __setup__}
  end

  def self.__setup__
    return if @setup_completed
    @setup_completed = true

    subclass = self
    superclass = subclass.superclass == CustomElement ? 'HTMLElement' : subclass.superclass.name.gsub(/::/, '__')
    class_name = subclass.name.gsub(/::/, '__')
    js = <<~JS
      #{class_name} = class extends #{superclass} {
        constructor() {
          super()
          if (this.constructor === #{class_name}) {
            setTimeout(()=>{
              var id = RubyCustomElement.objectId(this)
              RubyCustomElement.objectRubyIdMap.set(this, rubyVM.eval('#{subclass.name}.construct('+id+').__id__').toJS())
              delete RubyCustomElement.idObjectMap[id]
            }, 0)
          }
        }
        static get observedAttributes() {
          return rubyVM.eval('#{subclass.name}.observed_attributes').toJS()
        }
        connectedCallback() {
          setTimeout(()=>{rubyVM.eval('ObjectSpace._id2ref('+RubyCustomElement.objectRubyIdMap.get(this)+').connected_callback')}, 0)
        }
        disconnectedCallback() {
          setTimeout(()=>{rubyVM.eval('ObjectSpace._id2ref('+RubyCustomElement.objectRubyIdMap.get(this)+').disconnected_callback')}, 0)
        }
        adoptedCallback() {
          setTimeout(()=>{rubyVM.eval('ObjectSpace._id2ref('+RubyCustomElement.objectRubyIdMap.get(this)+').adopted_callback')}, 0)
        }
        attributeChangedCallback(name, oldValue, newValue) {
          var intervalID = setInterval(()=>{
            if (RubyCustomElement.objectRubyIdMap.get(this)) {
              var rubyObjectId = RubyCustomElement.objectRubyIdMap.get(this)
              RubyCustomElement.attributeChanged.set(rubyObjectId, {name, oldValue, newValue})
              setTimeout(()=>{
                rubyVM.eval('CustomElement.attribute_changed_callback('+RubyCustomElement.objectRubyIdMap.get(this)+')')
              }, 0)
              clearInterval(intervalID)
            }
          }, 100)
        }
      }
    JS
    JS.eval(js)
  rescue JS::Error => e
    p e
    raise
  end

  def self.construct(id)
    obj = self.allocate
    obj.instance_variable_set(:@this, JSrb.global[:RubyCustomElement][:idObjectMap].get(id))
    object_map[id] = obj
    obj.__send__ :initialize
    obj
  end

  def self.attribute_changed_callback(id)
    x = ObjectSpace._id2ref(id)
    name, old_value, new_value = *JSrb.global[:RubyCustomElement][:attributeChanged].get(x.__id__).to_h.values_at("name", "oldValue", "newValue")
    x.attribute_changed_callback(name, old_value, new_value)
  end

  def connected_callback
    # nothing
  end

  def disconnected_callback
    # nothing
  end

  def adopted_callback
    # nothing
  end

  def attribute_changed_callback(name, old_value, new_value)
    # nothing
  end

  def method_missing(...)
    @this.__send__(...)
  end

  def respond_to_missing?(name)
    !!@this[name]
  end
end
