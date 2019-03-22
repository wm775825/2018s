#### 1. 运行`lua.lua`和`lua-repl.lua`回答问题：
- 在th中运行`lua.lua`时，发现以下问题：
    + 定义一个`local`变量之后，后面行的代码无法引用它，会报错为正在引用一个`global`变量。这是因为在交互式环境中，一行代码作为一个作用域，出了这一行就出了这个作用域，所以在后边对它的引用会指向一个不存在或前边定义过的`global`变量。
    + 
- 不熟悉的语言特性：
    + 闭包。
    ```lua
    function make_counter()
        local counter = 0
        return function()
            counter = counter + 1
            return counter
        end
    end
    local ctr = make_counter()
    print(ctr())    -- 1
    print(ctr())    -- 2
    ```
    `make_counter()`函数执行时，除了返回`ctr`以外，其运行需要的`counter`会被复制到堆上，该`ctr`被调用时会调用堆上的`counter`。
    + `metatable`和`metamethod`。每个`table`可以将任意`table`作为自己的`metatable`。调用`table`的方法时，如果`table`中不存在，则在`metatable`中查找对应方法，可以用于修改和添加`table`中的方法和值，实现重载和继承机制。
    ```lua
    local t = {}
    function __index(t, k)
        print('__index', t, k)
        return 0
    end

    print(t.a)
    setmetatable(t, {__index = __index})
    print(t.a)
    print(t[1])
    ```
    `t.a`和`t[1]`本是`nil`，但是设置`metatable`的`__index`属性之后，`__index`的返回值会作为`t.a`和`t[1]`的值。
- 原`fib`函数为指数时间复杂度。改进：将递归改为DP。
```lua
local fib = {}
function fib_index(t, k)
  for i = 0, k do
    if i == 0 or i == 1 then t[i] = 1
    else
        t[i] = t[i - 1] + t[i - 2]
    end
  end
  return t[k]
end
setmetatable(fib, {__index = fib_index})
print(fib[30])
```
#### 2. 请问这样的代码存在什么问题（分析时间复杂度)? 如何改进?
``` lua
str = ""
for k, v in pairs(t) do
  str = str .. k .. v
end
```
- Lua中的字符串都是不可变的，因此每次进行字符串连接时都需要将原字符串拷贝一次，则每次的相对拷贝量为1、2、3、...，因此时间复杂度为O(n^2^)。同时，字符串连接之后，源字符串等待回收，当待回收的内存达到一定大小时会调用GC。因此，若字符串达到一定长度，可能每次连接都会调用GC，这也是一笔很大的开销。
- 改进思路是，将要连接的每一个字符串依次`insert`到一张`table`中，最后使用`table.concat()`将所有字符串连接起来。
- 测试程序如下：
```lua
str = ""
begin = os.clock()
for i = 1, 50000 do
   str = str.."Helloworld!"
end
endt = os.clock()
print((endt - begin).."s")  -- 9.8125s

t = {}
begin = os.clock()
for i = 1, 50000 do
   table.insert(t, "Helloworld!")
end
table.concat(t, "")
endt = os.clock()
print((endt - begin).."s")  -- 0.015625s
```
#### 3. 阻塞改为非阻塞
在 Part 2: RPC, 你需要实现 inst.k_async() 函数, 虽然函数名字里有 async (异步), 但仍然是阻塞式的调用. 如果要改成非阻塞式, 应该怎么做?
信号量？
