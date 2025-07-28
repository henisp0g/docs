Syntax 
Luau uses the baseline syntax of Lua 5.1. For detailed documentation, please refer to the Lua manual, this is an example:

local function tree_insert(tree, x)
    local lower, equal, greater = split(tree.root, x)
    if not equal then
        equal = {
            x = x,
            y = math.random(0, 2^31-1),
            left = nil,
            right = nil
        }
    end
    tree.root = merge3(lower, equal, greater)
end

Note that future versions of Lua extend the Lua 5.1 syntax with more features; Luau does support string literal extensions but does not support other 5.x additions; for details please refer to compatibility section.

The rest of this document documents additional syntax used in Luau.


String literals
Luau implements support for hexadecimal (\x), Unicode (\u) and \z escapes for string literals. This syntax follows Lua 5.3 syntax:

\xAB inserts a character with the code 0xAB into the string
\xAB inserts a character with the code 0xAB into the string
\xAB inserts a character with the code 0xAB into the string

Number literal
In addition to basic integer and floating-point decimal numbers, Luau supports:

Hexadecimal integer literals, 0xABC or 0XABC
Binary integer literals, 0b01010101 or 0B01010101
Decimal separators in all integer literals, using _ for readability: 1_048_576, 0xFFFF_FFFF, 0b_0101_0101

Note that Luau only has a single number type, a 64-bit IEEE754 double precision number (which can represent integers up to 2^53 exactly), and larger integer literals are stored with precision loss.


Continue statement
In addition to break in all loops, Luau supports continue statement. Similar to break, continue must be the last statement in the block.
Note that unlike break, continue is not a keyword. This is required to preserve backwards compatibility with existing code; so this is a continue statement:

if x < 0 then
    continue
end

Whereas this is a function call:

if x < 0 then
    continue()
end

When used in repeat..until loops, continue can not skip the declaration of a local variable if that local variable is used in the loop condition; code like this is invalid and won’t compile:

repeat
    do continue end
    local a = 5
until a > 0


Compound assignments
Luau supports compound assignments with the following operators: +=, -=, *=, /=, //=, %=, ^=, ..=. Just like regular assignments, compound assignments are statements, not expressions:

-- this works
a += 1

-- this doesn't work
print(a += 1)

Compound assignments only support a single value on the left and right hand side; additionally, the function calls on the left hand side are only evaluated once:

-- calls foo() twice
a[foo()] = a[foo()] + 1

-- calls foo() once
a[foo()] += 1

Compound assignments call the arithmetic metamethods (__add et al) and table indexing metamethods (__index and __newindex) as needed - for custom types no extra effort is necessary to support them.


Type annotations
To support gradual typing, Luau supports optional type annotations for variables and functions, as well as declaring type aliases.
Types can be declared for local variables, function arguments and function return types using : as a separator:

function foo(x: number, y: string): boolean
    local k: string = y:rep(x)
    return k == "a"
end

In addition, the type of any expression can be overridden using a type cast :::

local k = (y :: string):rep(x)

There are several simple builtin types: any (represents inability of the type checker to reason about the type), nil, boolean, number, string and thread.
Function types are specified using the arguments and return types, separated with ->:

local foo: (number, string) -> boolean

To return no values or more than one, you need to wrap the return type position with parentheses, and then list your types there.

local no_returns: (number, string) -> ()
local returns_boolean_and_string: (number, string) -> (boolean, string)

function foo(x: number, y: number): (number, string)
    return x + y, tostring(x) .. tostring(y)
end

Note that function types are specified without the argument names in the examples above, but it’s also possible to specify the names (that are not semantically significant but can show up in documentation and autocomplete):

local callback: (errorCode: number, errorText: string) -> ()

Table types are specified using the table literal syntax, using : to separate keys from values:

local array: { [number] : string }
local object: { x: number, y: string }

When the table consists of values keyed by numbers, it’s called an array-like table and has a special short-hand syntax, {T} (e.g. {string}).
Additionally, the type syntax supports type intersections (((number) -> string) & ((boolean) -> string)) and unions ((number | boolean) -> string). An intersection represents a type with values that conform to both sides at the same time, which is useful for overloaded functions; a union represents a type that can store values of either type - any is technically a union of all possible types.
It’s common in Lua for function arguments or other values to store either a value of a given type or nil; this is represented as a union (number | nil), but can be specified using ? as a shorthand syntax (number?).
In addition to declaring types for a given value, Luau supports declaring type aliases via type syntax:

type Point = { x: number, y: number }
type Array<T> = { [number]: T }
type Something = typeof(string.gmatch("", "%d"))

The right hand side of the type alias can be a type definition or a typeof expression; typeof expression doesn’t evaluate its argument at runtime.
By default type aliases are local to the file they are declared in. To be able to use type aliases in other modules using require, they need to be exported:

export type Point = { x: number, y: number }

An exported type can be used in another module by prefixing its name with the require alias that you used to import the module.

local M = require(Other.Module)

local a: M.Point = {x=5, y=6}

For more information please refer to typechecking documentation.


If-then-else expressions
In addition to supporting standard if statements, Luau adds support for if expressions. Syntactically, if-then-else expressions look very similar to if statements. However instead of conditionally executing blocks of code, if expressions conditionally evaluate expressions and return the value produced as a result. Also, unlike if statements, if expressions do not terminate with the end keyword.
Here is a simple example of an if-then-else expression:

local maxValue = if a > b then a else b

if-then-else expressions may occur in any place a regular expression is used. The if-then-else expression must match if <expr> then <expr> else <expr>; it can also contain an arbitrary number of elseif clauses, like if <expr> then <expr> elseif <expr> then <expr> else <expr>. Note that in either case, else is mandatory.
Here’s is an example demonstrating elseif:

local sign = if x < 0 then -1 elseif x > 0 then 1 else 0

Note: In Luau, the if-then-else expression is preferred vs the standard Lua idiom of writing a and b or c (which roughly simulates a ternary operator). However, the Lua idiom may return an unexpected result if b evaluates to false. The if-then-else expression will behave as expected in all situations.


Generalized iteration
Luau uses the standard Lua syntax for iterating through containers, for vars in values, but extends the semantics with support for generalized iteration. In Lua, to iterate over a table you need to use an iterator like next or a function that returns one like pairs or ipairs. In Luau, you can simply iterate over a table:

for k, v in {1, 4, 9} do
    assert(k * k == v)
end

This works for tables but can also be extended for tables or userdata by implementing __iter metamethod that is called before the iteration begins, and should return an iterator function like next (or a custom one):

local obj = { items = {1, 4, 9} }
setmetatable(obj, { __iter = function(o) return next, o.items end })

for k, v in obj do
    assert(k * k == v)
end

The default iteration order for tables is specified to be consecutive for elements 1..#t and unordered after that, visiting every element; similarly to iteration using pairs, modifying the table entries for keys other than the current one results in unspecified behavior.


String interpolation
Luau adds an additional way to define string values that allows you to place runtime expressions directly inside specific spots of the literal.
This is a more ergonomic alternative over using string.format or ("literal"):format.
To use string interpolation, use a backtick string literal:

local count = 3
print(`Bob has {count} apple(s)!`)
--> Bob has 3 apple(s)!

Any expression can be used inside {}:

local combos = {2, 7, 1, 8, 5}
print(`The lock combination is {table.concat(combos)}.`)
--> The lock combination is 27185.

Inside backtick string literal, \ is used to escape `, {, \ itself and a newline:

print(`Some example escaping the braces \{like so}`)
--> Some example escaping the braces {like so}

print(`Backslash \ that escapes the space is not a part of the string...`)
--> Backslash  that escapes the space is not a part of the string...

print(`Backslash \\ will escape the second backslash...`)
--> Backslash \ will escape the second backslash...

print(`Some text that also includes \`...`)
--> Some text that also includes `...

local name = "Luau"

print(`Welcome to {
    name
}!`)
--> Welcome to Luau!


Restrictions and limitations
The sequence of two opening braces {{ is rejected with a parse error. This restriction is made to prevent developers using other programming languages with a similar feature from trying to attempt that as a way to escape a single { and getting unexpected results in Luau.
Luau currently does not support backtick string literals in type annotations, therefore type Foo = `Foo` is invalid syntax.
Unlike single and double-quoted string literals, backtick string literals must always be wrapped in parentheses for function calls:

print "hello" -- valid 
print`hello` -- invalid syntax
print(`hello`) -- valid


Floor division (//)
Luau supports floor division, including its operator (//), its compound assignment operator (//=), and overloading metamethod (__idiv), as an ergonomic alternative to math.floor.
For numbers, a // b is equal to math.floor(a / b):

local n = 6.72
print(n // 2) --> 3
n //= 3
print(n) --> 2

Note that it’s possible to get inf, -inf, or NaN with floor division; when b is 0, a // b results in positive or negative infinity, and when both a and b are 0, a // b results in NaN.
For native vectors, c // d applies math.floor to each component of the vector c. Therefore c // d is equivalent to vector.create(math.floor(c.x / d), math.floor(c.y / b), math.floor(c.z / b)).
Floor division syntax and semantics follow from Lua 5.3 where applicable.



Type checking
Luau supports a gradual type system through the use of type annotations and type inference.

Type inference modes
There are three modes currently available. They must be annotated on the top few lines among the comments.

--!nocheck,

--!nonstrict (default), and

--!strict

nocheck mode will simply not start the type inference engine whatsoever.

As for the other two, they are largely similar but with one important difference: in nonstrict mode, we infer any for most of the types if we couldn’t figure it out early enough. This means that given this snippet:

local foo = 1

We can infer foo to be of type number, whereas the foo in the snippet below is inferred any:

local foo
foo = 1

However, given the second snippet in strict mode, the type checker would be able to infer number for foo.


Structural type system
Luau’s type system is structural by default, which is to say that we inspect the shape of two tables to see if they are similar enough. This was the obvious choice because Lua 5.1 is inherently structural.

type A = {x: number, y: number, z: number?}
type B = {x: number, y: number, z: number}

local a1: A = {x = 1, y = 2}        -- ok
local b1: B = {x = 1, y = 2, z = 3} -- ok

local a2: A = b1 -- ok
local b2: B = a1 -- not ok


Builtin types
The Luau VM supports 10 primitive types: nil, string, number, boolean, table, function, thread, userdata, vector, and buffer. Of these, table and function are not represented by name, but have their dedicated syntax as covered in this syntax document, userdata is represented by concrete types, while vector is not representable by name at all; other types can be specified by their name.
The type checker also provides the builtin types unknown, never, and any.

local s = "foo"
local n = 1
local b = true
local t = coroutine.running()

local a: any = 1
print(a.x) -- Type checker believes this to be ok, but crashes at runtime.

There’s a special case where we intentionally avoid inferring nil. It’s a good thing because it’s never useful for a local variable to always be nil, thereby permitting you to assign things to it for Luau to infer that instead.

local a
local b = nil

unknown type
unknown is also said to be the top type, that is it’s a union of all types.

local a: unknown = "hello world!"
local b: unknown = 5
local c: unknown = function() return 5 end

Unlike any, unknown will not allow itself to be used as a different type!

local function unknown(): unknown
    return if math.random() > 0.5 then "hello world!" else 5
end

local a: string = unknown() -- not ok
local b: number = unknown() -- not ok
local c: string | number = unknown() -- not ok

In order to turn a variable of type unknown into a different type, you must apply type refinements on that variable.

local x = unknown()
if typeof(x) == "number" then
    -- x : number
end

never type
never is also said to be the bottom type, meaning there doesn’t exist a value that inhabits the type never. In fact, it is the dual of unknown. never is useful in many scenarios, and one such use case is when type refinements proves it impossible:

local x = unknown()
if typeof(x) == "number" and typeof(x) == "string" then
    -- x : never
end

any type
any is just like unknown, except that it allows itself to be used as an arbitrary type without further checks or annotations. Essentially, it’s an opt-out from the type system entirely.

local x: any = 5
local y: string = x -- no type errors here

Function types
Let’s start with something simple.

local function f(x) return x end

local a: number = f(1)     -- ok
local b: string = f("foo") -- ok
local c: string = f(true)  -- not ok

In strict mode, the inferred type of this function f is <A>(A) -> A (take a look at generics), whereas in nonstrict we infer (any) -> any. We know this is true because f can take anything and then return that. If we used x with another concrete type, then we would end up inferring that.
Similarly, we can infer the types of the parameters with ease. By passing a parameter into anything that also has a type, we are saying “this and that has the same type.”

local function greetingsHelper(name: string)
    return "Hello, " .. name
end

local function greetings(name)
    return greetingsHelper(name)
end

print(greetings("Alexander"))          -- ok
print(greetings({name = "Alexander"})) -- not ok


Table types
From the type checker perspective, each table can be in one of three states. They are: unsealed table, sealed table, and generic table. This is intended to represent how the table’s type is allowed to change.

Unsealed tables
An unsealed table is a table which supports adding new properties, which updates the tables type. Unsealed tables are created using table literals. This is one way to accumulate knowledge of the shape of this table.

local t = {x = 1} -- {x: number}
t.y = 2           -- {x: number, y: number}
t.z = 3           -- {x: number, y: number, z: number}

However, if this local were written as local t: { x: number } = { x = 1 }, it ends up sealing the table, so the two assignments henceforth will not be ok.
Furthermore, once we exit the scope where this unsealed table was created in, we seal it.

local function vec2(x, y)
    local t = {}
    t.x = x
    t.y = y
    return t
end

local v2 = vec2(1, 2)
v2.z = 3 -- not ok

Unsealed tables are exact in that any property of the table must be named by the type. Since Luau treats missing properties as having value nil, this means that we can treat an unsealed table which does not mention a property as if it mentioned the property, as long as that property is optional.

local t = {x = 1}
local u : { x : number, y : number? } = t -- ok because y is optional
local v : { x : number, z : number } = t  -- not ok because z is not optional

Sealed tables
A sealed table is a table that is now locked down. This occurs when the table type is spelled out explicitly via a type annotation, or if it is returned from a function.

local t : { x: number } = {x = 1}
t.y = 2 -- not ok

Sealed tables are inexact in that the table may have properties which are not mentioned in the type. As a result, sealed tables support width subtyping, which allows a table with more properties to be used as a table with fewer properties.

type Point1D = { x : number }
type Point2D = { x : number, y : number }
local p : Point2D = { x = 5, y = 37 }
local q : Point1D = p -- ok because Point2D has more properties than Point1D

Generic tables
This typically occurs when the symbol does not have any annotated types or were not inferred anything concrete. In this case, when you index on a parameter, you’re requesting that there is a table with a matching interface.

local function f(t)
    return t.x + t.y
           --^   --^ {x: _, y: _}
end

f({x = 1, y = 2})        -- ok
f({x = 1, y = 2, z = 3}) -- ok
f({x = 1})               -- not ok

Table indexers
These are particularly useful for when your table is used similarly to an array.

local t = {"Hello", "world!"} -- {[number]: string}
print(table.concat(t, ", "))

Luau supports a concise declaration for array-like tables, {T} (for example, {string} is equivalent to {[number]: string}); the more explicit definition of an indexer is still useful when the key isn’t a number, or when the table has other fields like { [number]: string, n: number }.

Generics
The type inference engine was built from the ground up to recognize generics. A generic is simply a type parameter in which another type could be slotted in. It’s extremely useful because it allows the type inference engine to remember what the type actually is, unlike any.

type Pair<T> = {first: T, second: T}

local strings: Pair<string> = {first="Hello", second="World"}
local numbers: Pair<number> = {first=1, second=2}

Generic functions
As well as generic type aliases like Pair<T>, Luau supports generic functions. These are functions that, as well as their regular data parameters, take type parameters. For example, a function which reverses an array is:

function reverse(a)
  local result = {}
  for i = #a, 1, -1 do
    table.insert(result, a[i])
  end
  return result
end

The type of this function is that it can reverse an array, and return an array of the same type. Luau can infer this type, but if you want to be explicit, you can declare the type parameter T, for example:

function reverse<T>(a: {T}): {T}
  local result: {T} = {}
  for i = #a, 1, -1 do
    table.insert(result, a[i])
  end
  return result
end

When a generic function is called, Luau infers type arguments, for example

local x: {number} = reverse({1, 2, 3})
local y: {string} = reverse({"a", "b", "c"})

Generic types are used for built-in functions as well as user functions, for example the type of two-argument table.insert is:

<T>({T}, T) -> ()

Union types
A union type represents one of the types in this set. If you try to pass a union onto another thing that expects a more specific type, it will fail.
For example, what if this string | number was passed into something that expects number, but the passed in value was actually a string?

local stringOrNumber: string | number = "foo"

local onlyString: string = stringOrNumber -- not ok
local onlyNumber: number = stringOrNumber -- not ok
Note: it’s impossible to be able to call a function if there are two or more function types in this union.

Intersection types
An intersection type represents all of the types in this set. It’s useful for two main things: to join multiple tables together, or to specify overloadable functions.

type XCoord = {x: number}
type YCoord = {y: number}
type ZCoord = {z: number}

type Vector2 = XCoord & YCoord
type Vector3 = XCoord & YCoord & ZCoord

local vec2: Vector2 = {x = 1, y = 2}        -- ok
local vec3: Vector3 = {x = 1, y = 2, z = 3} -- ok

type SimpleOverloadedFunction = ((string) -> number) & ((number) -> string)

local f: SimpleOverloadedFunction

local r1: number = f("foo") -- ok
local r2: number = f(12345) -- not ok
local r3: string = f("foo") -- not ok
local r4: string = f(12345) -- ok
Note: it’s impossible to create an intersection type of some primitive types, e.g. string & number, or string & boolean, or other variations thereof.

Note: Luau still does not support user-defined overloaded functions. Some of Roblox and Lua 5.1 functions have different function signature, so inherently requires overloaded functions.

Singleton types (aka literal types)
Luau’s type system also supports singleton types, which means it’s a type that represents one single value at runtime. At this time, both string and booleans are representable in types.

We do not currently support numbers as types. For now, this is intentional.

local foo: "Foo" = "Foo" -- ok
local bar: "Bar" = foo   -- not ok
local baz: string = foo  -- ok

local t: true = true -- ok
local f: false = false -- ok
This happens all the time, especially through type refinements and is also incredibly useful when you want to enforce program invariants in the type system! See tagged unions for more information.

Variadic types
Luau permits assigning a type to the ... variadic symbol like any other parameter:

local function f(...: number)
end

f(1, 2, 3)     -- ok
f(1, "string") -- not ok
f accepts any number of number values.

In type annotations, this is written as ...T:

type F = (...number) -> ...string
Type packs
Multiple function return values as well as the function variadic parameter use a type pack to represent a list of types.

When a type alias is defined, generic type pack parameters can be used after the type parameters:

type Signal<T, U...> = { f: (T, U...) -> (), data: T }
Keep in mind that ...T is a variadic type pack (many elements of the same type T), while U... is a generic type pack that can contain zero or more types and they don’t have to be the same.

It is also possible for a generic function to reference a generic type pack from the generics list:

local function call<T, U...>(s: Signal<T, U...>, ...: U...)
    s.f(s.data, ...)
end
Generic types with type packs can be instantiated by providing a type pack:

local signal: Signal<string, (number, number, boolean)> = --

call(signal, 1, 2, false)
There are also other ways to instantiate types with generic type pack parameters:

type A<T, U...> = (T) -> U...

type B = A<number, ...string> -- with a variadic type pack
type C<S...> = A<number, S...> -- with a generic type pack
type D = A<number, ()> -- with an empty type pack
Trailing type pack argument can also be provided without parentheses by specifying variadic type arguments:

type List<Head, Rest...> = (Head, Rest...) -> ()

type B = List<number> -- Rest... is ()
type C = List<number, string, boolean> -- Rest is (string, boolean)

type Returns<T...> = () -> T...

-- When there are no type parameters, the list can be left empty
type D = Returns<> -- T... is ()
Type pack parameters are not limited to a single one, as many as required can be specified:

type Callback<Args..., Rets...> = { f: (Args...) -> Rets... }

type A = Callback<(number, string), ...number>
Adding types for faux object oriented programs
One common pattern we see with existing Lua/Luau code is the following object-oriented code. While Luau is capable of inferring a decent chunk of this code, it cannot pin down on the types of self when it spans multiple methods.

local Account = {}
Account.__index = Account

function Account.new(name, balance)
    local self = {}
    self.name = name
    self.balance = balance

    return setmetatable(self, Account)
end

-- The `self` type is different from the type returned by `Account.new`
function Account:deposit(credit)
    self.balance += credit
end

-- The `self` type is different from the type returned by `Account.new`
function Account:withdraw(debit)
    self.balance -= debit
end

local account = Account.new("Alexander", 500)
For example, the type of Account.new is <a, b>(name: a, balance: b) -> { ..., name: a, balance: b, ... } (snipping out the metatable). For better or worse, this means you are allowed to call Account.new(5, "hello") as well as Account.new({}, {}). In this case, this is quite unfortunate, so your first attempt may be to add type annotations to the parameters name and balance.

There’s the next problem: the type of self is not shared across methods of Account, this is because you are allowed to explicitly opt for a different value to pass as self by writing account.deposit(another_account, 50). As a result, the type of Account:deposit is <a, b>(self: { balance: a }, credit: b) -> (). Consequently, Luau cannot infer the result of the + operation from a and b, so a type error is reported.

We can see there’s a lot of problems happening here. This is a case where you’ll have to provide some guidance to Luau in the form of annotations today, but the process is straightforward and without repetition. You first specify the type of data you want your class to have, and then you define the class type separately with setmetatable (either via typeof, or in the New Type Solver, the setmetatable type function). From then on, you can explicitly annotate the self type of each method with your class type! Note that while the definition is written e.g. Account.deposit, you can still call it as account:deposit(...).

local Account = {}
Account.__index = Account

type AccountData = {
    name: string,
    balance: number,
}

export type Account = typeof(setmetatable({} :: AccountData, Account))
-- or alternatively, in the new type solver...
-- export type Account = setmetatable<AccountData, typeof(Account)>


-- this return annotation is not required, but ensures that you cannot
-- accidentally make the constructor incompatible with the methods
function Account.new(name, balance): Account
    local self = {}
    self.name = name
    self.balance = balance

    return setmetatable(self, Account)
end

-- this annotation on `self` is the only _required_ annotation.
function Account.deposit(self: Account, credit)
    -- autocomplete on `self` works here!
    self.balance += credit
end

-- this annotation on `self` is the only _required_ annotation.
function Account.withdraw(self: Account, debit)
    -- autocomplete on `self` works here!
    self.balance -= debit
end

local account = Account.new("Hina", 500)
account:deposit(20) -- this still works, and we had autocomplete after hitting `:`!
Based on feedback, we plan to restrict the types of all functions defined with : syntax to share their self types. This will enable future versions of this code to work without any explicit self annotations because it amounts to having type inference make precisely the assumptions we are encoding with annotations here — namely, that the type of the constructors and the method definitions is intended by the developer to be the same.

Tagged unions
Tagged unions are just union types! In particular, they’re union types of tables where they have at least some common properties but the structure of the tables are different enough. Here’s one example:

type Ok<T> = { type: "ok", value: T }
type Err<E> = { type: "err", error: E }
type Result<T, E> = Ok<T> | Err<E>
This Result<T, E> type can be discriminated by using type refinements on the property type, like so:

if result.type == "ok" then
    -- result is known to be Ok<T>
    -- and attempting to index for error here will fail
    print(result.value)
elseif result.type == "err" then
    -- result is known to be Err<E>
    -- and attempting to index for value here will fail
    print(result.error)
end
Which works out because value: T exists only when type is in actual fact "ok", and error: E exists only when type is in actual fact "err".

Type refinements
When we check the type of any lvalue (a global, a local, or a property), what we’re doing is we’re refining the type, hence “type refinement.” The support for this is arbitrarily complex, so go at it!

Here are all the ways you can refine:

Truthy test: if x then will refine x to be truthy.

Type guards: if type(x) == "number" then will refine x to be number.

Equality: if x == "hello" then will refine x to be a singleton type "hello".

And they can be composed with many of and/or/not. not, just like ~=, will flip the resulting refinements, that is not x will refine x to be falsy.

The assert(..) function may also be used to refine types instead of if/then.

Using truthy test:

local maybeString: string? = nil

if maybeString then
    local onlyString: string = maybeString -- ok
    local onlyNil: nil = maybeString       -- not ok
end

if not maybeString then
    local onlyString: string = maybeString -- not ok
    local onlyNil: nil = maybeString       -- ok
end
Using type test:

local stringOrNumber: string | number = "foo"

if type(stringOrNumber) == "string" then
    local onlyString: string = stringOrNumber -- ok
    local onlyNumber: number = stringOrNumber -- not ok
end

if type(stringOrNumber) ~= "string" then
    local onlyString: string = stringOrNumber -- not ok
    local onlyNumber: number = stringOrNumber -- ok
end
Using equality test:

local myString: string = f()

if myString == "hello" then
    local hello: "hello" = myString -- ok because it is absolutely "hello"!
    local copy: string = myString   -- ok
end
And as said earlier, we can compose as many of and/or/not as we wish with these refinements:

local function f(x: any, y: any)
    if (x == "hello" or x == "bye") and type(y) == "string" then
        -- x is of type "hello" | "bye"
        -- y is of type string
    end

    if not (x ~= "hi") then
        -- x is of type "hi"
    end
end
assert can also be used to refine in all the same ways:

local stringOrNumber: string | number = "foo"

assert(type(stringOrNumber) == "string")

local onlyString: string = stringOrNumber -- ok
local onlyNumber: number = stringOrNumber -- not ok
Type casts
Expressions may be typecast using ::. Typecasting is useful for specifying the type of an expression when the automatically inferred type is too generic.

For example, consider the following table constructor where the intent is to store a table of names:

local myTable = {names = {}}
table.insert(myTable.names, 42)         -- Inserting a number ought to cause a type error, but doesn't
In order to specify the type of the names table a typecast may be used:


local myTable = {names = {} :: {string}}
table.insert(myTable.names, 42)         -- not ok, invalid 'number' to 'string' conversion
A typecast itself is also type checked to ensure that one of the conversion operands is the subtype of the other or any:

local numericValue = 1
local value = numericValue :: any             -- ok, all expressions may be cast to 'any'
local flag = numericValue :: boolean          -- not ok, invalid 'number' to 'boolean' conversion
When typecasting a variadic or the result of a function with multiple returns, only the first value will be preserved. The rest will be discarded.

function returnsMultiple(...): (number, number, number)
    print(... :: string) -- "x"
    return 1, 2, 3
end

print(returnsMultiple("x", "y", "z")) -- 1, 2, 3
print(returnsMultiple("x", "y", "z") :: number) -- 1
Roblox types
Roblox supports a rich set of classes and data types, documented here. All of them are readily available for the type checker to use by their name (e.g. Part or RaycastResult).

When one type inherits from another type, the type checker models this relationship and allows to cast a subclass to the parent class implicitly, so you can pass a Part to a function that expects an Instance.

All enums are also available to use by their name as part of the Enum type library, e.g. local m: Enum.Material = part.Material.

We can automatically deduce what calls like Instance.new and game:GetService are supposed to return:

local part = Instance.new("Part")
local basePart: BasePart = part
Finally, Roblox types can be refined using IsA:

local function getText(x : Instance) : string
    if x:IsA("TextLabel") or x:IsA("TextButton") or x:IsA("TextBox") then
        return child.Text
    end
    return ""
end
Note that many of these types provide some properties and methods in both lowerCase and UpperCase; the lowerCase variants are deprecated, and the type system will ask you to use the UpperCase variants instead.

Module interactions
Let’s say that we have two modules, Foo and Bar. Luau will try to resolve the paths if it can find any require in any scripts. In this case, when you say script.Parent.Bar, Luau will resolve it as: relative to this script, go to my parent and get that script named Bar.

-- Module Foo
local Bar = require(script.Parent.Bar)

local baz1: Bar.Baz = 1     -- not ok
local baz2: Bar.Baz = "foo" -- ok

print(Bar.Quux)         -- ok
print(Bar.FakeProperty) -- not ok

Bar.NewProperty = true -- not ok

-- Module Bar
export type Baz = string

local module = {}

module.Quux = "Hello, world!"

return module
There are some caveats here though. For instance, the require path must be resolvable statically, otherwise Luau cannot accurately type check it.

Cyclic module dependencies
Cyclic module dependencies can cause problems for the type checker. In order to break a module dependency cycle a typecast of the module to any may be used:

local myModule = require(MyModule) :: any
Type functions
Type functions are functions that run during analysis time and operate on types, instead of runtime values. They can use the types library to transform existing types or create new ones.

Here’s a simplified implementation of the builtin type function keyof. It takes a table type and returns its property names as a union of singletons.

type function simple_keyof(ty)
    -- Ignoring unions or intersections of tables for simplicity.
    if not ty:is("table") then
        error("Can only call keyof on tables.")
    end

    local union = nil

    for property in ty:properties() do
        union = if union then types.unionof(union, property) else property
    end

    return if union then union else types.singleton(nil)
end

type person = {
    name: string,
    age: number,
}
--- keys = "age" | "name"
type keys = simple_keyof<person>
Type function environment
In addition to the types library, type functions have access to:

assert, error, print

next, ipairs, pairs

select, unpack

getmetatable, setmetatable

rawget, rawset, rawlen, raweq

tonumber, tostring

type, typeof

math library

table library

string library

bit32 library

utf8 library

buffer library

types library
The types library is used to create and transform types, and can only be used within type functions.

types library properties

types.any
The any type.


types.unknown
The unknown type.

types.never
The never type.

types.boolean
The boolean type.

types.buffer
The buffer type.

types.number
The number type.

types.string
The string type.

types.thread
The thread type.

types library functions

types.singleton(arg: string | boolean | nil): type
Returns the singleton type of the argument.

Copy
types.negationof(arg: type): type
Returns an immutable negation of the argument type.

types.optional(arg: type): type
Returns a version of the given type that is now optional.

If the given type is a union type, nil will be added unconditionally as a component.

Otherwise, the result will be a union of the given type and the nil type.

types.unionof(first: type, second: type, ...: type): type
Returns an immutable union of two or more arguments.

types.intersectionof(first: type, second: type, ...: type): type
Returns an immutable intersection of two or more arguments.

types.newtable(props: { [type]: type | { read: type?, write: type? } }?, indexer: { index: type, readresult: type, writeresult: type? }?, metatable: type?): type
Returns a fresh, mutable table type. Property keys must be string singleton types. The table’s metatable is set if one is provided.

Copy
types.newfunction(parameters: { head: {type}?, tail: type? }, returns: { head: {type}?, tail: type? }?, generics: {type}?): type
Returns a fresh, mutable function type, using the ordered parameters of head and the variadic tail of tail.

types.copy(arg: type): type
Returns a deep copy of the argument type.

types.generic(name: string?, ispack: boolean?): type
Creates a generic named name. If ispack is true, the result is a generic pack.

type instance
type instances can have extra properties and methods described in subsections depending on its tag.

type.tag: "nil" | "unknown" | "never" | "any" | "boolean" | "number" | "string" | "singleton" | "negation" | "union" | "intersection" | "table" | "function" | "class" | "thread" | "buffer"
An immutable property holding the type’s tag.

__eq(arg: type): boolean
Overrides the == operator to return true if self is syntactically equal to arg. This excludes semantically equivalent types, true | false is unequal to boolean.

type:is(arg: "nil" | "unknown" | "never" | "any" | "boolean" | "number" | "string" | "singleton" | "negation" | "union" | "intersection" | "table" | "function" | "class" | "thread" | "buffer")
Returns true if self has the argument as its tag.

Singleton type instance

singletontype:value(): boolean | nil | "string"
Returns the singleton’s actual value, like true for types.singleton(true).

Generic type instance
Copy
generictype:name(): string?
Returns the name of the generic or nil if it has no name.

generictype:ispack(): boolean
Returns true if the generic is a pack, or false otherwise.

Table type instance

tabletype:setproperty(key: type, value: type?)
Sets the type of the property for the given key, using the same type for both reading from and writing to the table.

key is expected to be a string singleton type, naming the property.

value will be set as both the read type and write type of the property.

If value is nil, the property is removed.

tabletype:setreadproperty(key: type, value: type?)
Sets the type for reading from the property named by key, leaving the type for writing this property as-is.

key is expected to be a string singleton type, naming the property.

value will be set as the read type, the write type will be unchanged.

If key is not already present, only a read type will be set, making the property read-only.

If value is nil, the property is removed.

tabletype:setwriteproperty(key: type, value: type?)
Sets the type for writing to the property named by key, leaving the type for reading this property as-is.

key is expected to be a string singleton type, naming the property.

value will be set as the write type, the read type will be unchanged.

If key is not already present, only a write type will be set, making the property write-only.

If value is nil, the property is removed.

tabletype:readproperty(key: type): type?
Returns the type used for reading values from this property, or nil if the property doesn’t exist.

Copy
tabletype:writeproperty(key: type): type?
Returns the type used for writing values to this property, or nil if the property doesn’t exist.

tabletype:properties(): { [type]: { read: type?, write: type? } }
Returns a table mapping property keys to their read and write types.

tabletype:setindexer(index: type, result: type)
Sets the table’s indexer, using the same type for reads and writes.

tabletype:setreadindexer(index: type, result: type)
Sets the type resulting from reading from this table via indexing.

tabletype:setwriteindexer(index: type, result: type)
Sets the type for writing to this table via indexing.

tabletype:indexer(): { index: type, readresult: type, writeresult: type }
Returns the table’s indexer as a table, or nil if it doesn’t exist.

tabletype:readindexer(): { index: type, result: type }?
Returns the table’s indexer using the result’s read type, or nil if it doesn’t exist.

tabletype:writeindexer()
Returns the table’s indexer using the result’s write type, or nil if it doesn’t exist.

tabletype:setmetatable(arg: type)
Sets the table’s metatable.

tabletype:metatable(): type?
Gets the table’s metatable, or nil if it doesn’t exist.

Function type instance

functiontype:setparameters(head: {type}?, tail: type?)
Sets the function’s parameters, with the ordered parameters in head and the variadic tail in tail.

functiontype:parameters(): { head: {type}?, tail: type? }
Returns the function’s parameters, with the ordered parameters in head and the variadic tail in tail.

functiontype:setreturns(head: {type}?, tail: type?)
Sets the function’s return types, with the ordered parameters in head and the variadic tail in tail.

functiontype:returns(): { head: {type}?, tail: type? }
Returns the function’s return types, with the ordered parameters in head and the variadic tail in tail.

functiontype:generics(): {type}
Returns an array of the function’s generic types.

functiontype:setgenerics(generics: {type}?)
Sets the function’s generic types.

Negation type instance

type:inner(): type
Returns the type being negated.

Union type instance

uniontype:components(): {type}
Returns an array of the unioned types.

Intersection type instance

intersectiontype:components()
Returns an array of the intersected types.

Class type instance

classtype:properties(): { [type]: { read: type?, write: type? } }
Returns the properties of the class with their respective read and write types.

classtype:readparent(): type?
Returns the type of reading this class’ parent, or returns nil if the parent class doesn’t exist.

classtype:writeparent(): type?
Returns the type for writing to this class’ parent, or returns nil if the parent class doesn’t exist.

classtype:metatable(): type?
Returns the class’ metatable, or nil if it doesn’t exist.

classtype:indexer(): { index: type, readresult: type, writeresult: type }?
Returns the class’ indexer, or nil if it doesn’t exist.

classtype:readindexer(): { index: type, result: type }?
Returns result type of reading from the class via indexing, or nil if it doesn’t exist.

classtype:writeindexer(): { index: type, result: type }?
Returns the type for writing to the class via indexing, or nil if it doesn’t exist.


Performance
One of main goals of Luau is to enable high performance code, with gameplay code being the main use case. This can be viewed as two separate goals:
Make idiomatic code that wasn’t tuned faster
Enable even higher performance through careful tuning
Both of these goals are important - it’s insufficient to just focus on the highly tuned code, and all things being equal we prefer to raise all boats by implementing general optimizations. However, in some cases it’s important to be aware of optimizations that Luau does and doesn’t do.
Worth noting is that Luau is focused on, first and foremost, stable high performance code in interpreted context. This is because JIT compilation is not available on many platforms Luau runs on, and AOT compilation would only work for code that Roblox ships (and even that does not always work). This is in stark contrast with LuaJIT that, while providing an excellent interpreter as well, focuses a lot of the attention on JIT (with many optimizations unavailable in the interpreter).
Having said that, Luau has been updated to include an optional JIT component for x64 and arm64 platforms. This component can compile a selected set of functions, including limiting compilation to functions or modules marked explicitly by the user. While functions can be compiled at any time, automated JIT compilation decisions based on statistics/tracing are not performed. Luau JIT takes into account the type annotations present in the source code to specialize code paths and at this time, doesn’t include runtime analysis of the types/values flowing through the program.
The rest of this document goes into some optimizations that Luau employs and how to best leverage them when writing code. The document is not complete - a lot of optimizations are transparent to the user and involve detailed low-level tuning of various parts that is not described here - and all of this is subject to change without notice, as it doesn’t affect the semantics of valid code.

Fast bytecode interpreter
Luau features a very highly tuned portable bytecode interpreter. It’s similar to Lua interpreter in that it’s written in C, but it’s highly tuned to yield efficient assembly when compiled with Clang and latest versions of MSVC. On some workloads it can match the performance of LuaJIT interpreter which is written in highly specialized assembly. We are continuing to tune the interpreter and the bytecode format over time; while extra performance can be extracted by rewriting the interpreter in assembly, we’re unlikely to ever do that as the extra gains at this point are marginal, and we gain a lot from C in terms of portability and being able to quickly implement new optimizations.
Of course the interpreter isn’t typical C code - it uses many tricks to achieve extreme levels of performance and to coerce the compiler to produce efficient assembly. Due to a better bytecode design and more efficient dispatch loop it’s noticeably faster than Lua 5.x (including Lua 5.4 which made some of the changes similar to Luau, but doesn’t come close). The bytecode design was partially inspired by excellent LuaJIT interpreter. Most computationally intensive scripts only use the interpreter core loop and builtins, which on x64 compiles into ~16 KB, thus leaving half of the instruction cache for other infrequently called code.

Optimizing compiler
Unlike Lua and LuaJIT, Luau uses a multi-pass compiler with a frontend that parses source into an AST and a backend that generates bytecode from it. This carries a small penalty in terms of compilation time, but results in more flexible code and, crucially, makes it easier to optimize the generated bytecode.
Note: Compilation throughput isn’t the main focus in Luau, but our compiler is reasonably fast; with all currently implemented optimizations enabled, it compiles 950K lines of Luau code in 1 second on a single core of a desktop Ryzen 5900X CPU, producing bytecode and debug information.
While bytecode optimizations are limited due to the flexibility of Luau code (e.g. a * 1 may not be equivalent to a if * is overloaded through metatables), even in absence of type information Luau compiler can perform some optimizations such as “deep” constant folding across functions and local variables, perform upvalue optimizations for upvalues that aren’t mutated, do analysis of builtin function usage, optimize the instruction sequences for multiple variable assignments, and some peephole optimizations on the resulting bytecode. The compiler can also be instructed to use more aggressive optimizations by enabling optimization level 2 (-O2 in CLI tools), some of which are documented further on this page.
Most bytecode optimizations are performed on individual statements or functions, however the compiler also does a limited amount of interprocedural optimizations; notably, calls to local functions can be optimized with the knowledge of the argument count or number of return values involved. Interprocedural optimizations are limited to a single module due to the compilation model.
Luau compiler is also able to use type information to do further optimizations. Because we control the entire stack (unlike e.g. TypeScript where the type information is discarded completely before reaching the VM), we have more flexibility there and can make some tradeoffs during codegen even if the type system isn’t completely sound. For example, it might be reasonable to assume that in presence of known types, we can infer absence of side effects for arithmetic operations and builtins - if the runtime types mismatch due to intentional violation of the type safety through global injection, the code will still be safely sandboxed. Type information is currently limited to small peephole optimizations, but it has a potential to unlock optimizations such as common subexpression elimination and allocation hoisting in the future, without having to rely on a JIT. These future optimizations opportunities are speculative pending further research.

Epsilon-overhead debugger
It’s important for Luau to have stable and predictable performance. Something that comes up in Lua-based environments often is the use of line hooks to implement debugging (both for breakpoints and for stepping). This is problematic because the support for hooks is typically not free in general, but importantly once the hook is enabled, calling the hook has a considerable overhead, and the hook itself may be very costly to evaluate since it will need to associate the script:line pair with the breakpoint information.
Luau does not support hooks at all, and relies on first-class support for breakpoints (using bytecode patching) and single-stepping (using a custom interpreter loop) to implement debugging. As a result, the presence of breakpoints doesn’t slow the script execution down - the only noticeable discrepancy between running code under a debugger and without a debugger should be in cases where breakpoints are evaluated and skipped based on breakpoint conditions, or when stepping over long-running fragments of code.

Inline caching for table and global access
Table access for field lookup is optimized in Luau using a mechanism that blends inline caching (classically used in Java/JavaScript VMs) and HREFs (implemented in LuaJIT). Compiler can predict the hash slot used by field lookup, and the VM can correct this prediction dynamically.

As a result, field access can be very fast in Luau, provided that:
The field name is known at compile time. To make sure this is the case, table.field notation is recommended, although the compiler will also optimize table["field"] when the expression is known to be a constant string.
The field access doesn’t use metatables. The fastest way to work with tables in Luau is to store fields directly inside the table, and store methods in the metatable (see below); access to “static” fields in classic OOP designs is best done through Class.StaticField instead of object.StaticField.
The object structure is usually uniform. While it’s possible to use the same function to access tables of different shape - e.g. function getX(obj) return obj.x end can be used on any table that has a field "x" - it’s best to not vary the keys used in the tables too much, as it defeats this optimization.
The same optimization is applied to the custom globals declared in the script, although it’s best to avoid these altogether by using locals instead. Still, this means that the difference between function and local function is less pronounced in Luau.

Importing global access chains
While global access for library functions can be optimized in a similar way, this optimization breaks down when the global table is using sandboxing through metatables, and even when globals aren’t sandboxed, math.max still requires two table accesses.
It’s always possible to “localize” the global accesses by using local max = math.max, but this is cumbersome - in practice it’s easy to forget to apply this optimization. To avoid relying on programmers remembering to do this, Luau implements a special optimization called “imports”, where most global chains such as math.max are resolved when the script is loaded instead of when the script is executed.
This optimization relies on being able to predict the shape of the environment table for a given function; this is possible due to global sandboxing, however this optimization is invalid in some cases:
loadstring can load additional code that runs in context of the caller’s environment
getfenv/setfenv can directly modify the environment of any function
The use of any of these functions performs a dynamic deoptimization, marking the affected environment as “impure”. The optimizations are only in effect on functions with “pure” environments - because of this, the use of loadstring/getfenv/setfenv is not recommended. Note that getfenv deoptimizes the environment even if it’s only used to read values from the environment.
Note: Luau still supports these functions as part of our backwards compatibility promise, although we’d love to switch to Lua 5.2’s _ENV as that mechanism is cleaner and doesn’t require costly dynamic deoptimization.

Fast method calls
Luau specializes method calls to improve their performance through a combination of compiler, VM and binding optimizations. Compiler emits a specialized instruction sequence when methods are called through obj:Method syntax (while this isn’t idiomatic anyway, you should avoid obj.Method(obj)). When the object in question is a Lua table, VM performs some voodoo magic based on inline caching to try to quickly discover the implementation of this method through the metatable.
For this to be effective, it’s crucial that __index in a metatable points to a table directly. For performance reasons it’s strongly recommended to avoid __index functions as well as deep __index chains; an ideal object in Luau is a table with a metatable that points to itself through __index.
When the object in question is a reflected userdata, a special mechanism called “namecall” is used to minimize the interop cost. In classical Lua binding model, obj:Method is called in two steps, retrieving the function object (obj.Method) and calling it; both steps are often implemented in C++, and the method retrieval needs to use a method object cache - all of this makes method calls slow.
Luau can directly call the method by name using the “namecall” extension, and an optimized reflection layer can retrieve the correct method quickly through more voodoo magic based on string interning and custom Luau features that aren’t exposed through Luau scripts.
As a result of both optimizations, common Lua tricks of caching the method in a local variable aren’t very productive in Luau and aren’t recommended either.

Specialized builtin function calls
Due to global sandboxing and the ability to dynamically deoptimize code running in impure environments, in pure environments we go beyond optimizing the interpreter and optimize many built-in functions through a “fastcall” mechanism.
For this mechanism to work, function call must be “obvious” to the compiler - it needs to call a builtin function directly, e.g. math.max(x, 1), although it also works if the function is “localized” (local max = math.max); this mechanism doesn’t work for indirect function calls unless they were inlined during compilation, and doesn’t work for method calls (so calling string.byte is more efficient than s:byte).
The mechanism works by directly invoking a highly specialized and optimized implementation of a builtin function from the interpreter core loop without setting up a stack frame and omitting other work; additionally, some fastcall specializations are partial in that they don’t support all types of arguments, for example all math library builtins are only specialized for numeric arguments, so calling math.abs with a string argument will fall back to the slower implementation that will do string->number coercion.
As a result, builtin calls are very fast in Luau - they are still slightly slower than core instructions such as arithmetic operations, but only slightly so. The set of fastcall builtins is slowly expanding over time and as of this writing contains assert, type, typeof, rawget/rawset/rawequal, getmetatable/setmetatable, tonumber/tostring, all functions from math (except noise and random/randomseed) and bit32, and some functions from string and table library.
Some builtin functions have partial specializations that reduce the cost of the common case further. Notably:
assert is specialized for cases when the assertion return value is not used and the condition is truthy; this helps reduce the runtime cost of assertions to the extent possible
bit32.extract is optimized further when field and width selectors are constant
select is optimized when the second argument is ...; in particular, select(x, ...) is O(1) when using the builtin dispatch mechanism even though it’s normally O(N) in variadic argument count.
Some functions from math library like math.floor can additionally take advantage of advanced SIMD instruction sets like SSE4.1 when available.
In addition to runtime optimizations for builtin calls, many builtin calls, as well as constants like math.pi/math.huge, can also be constant-folded by the bytecode compiler when using aggressive optimizations (level 2); this currently applies to most builtin calls with constant arguments and a single return value. For builtin calls that can not be constant folded, compiler assumes knowledge of argument/return count (level 2) to produce more efficient bytecode instructions.

Optimized table iteration
Luau implements a fully generic iteration protocol; however, for iteration through tables in addition to generalized iteration (for .. in t) it recognizes three common idioms (for .. in ipairs(t), for .. in pairs(t) and for .. in next, t) and emits specialized bytecode that is carefully optimized using custom internal iterators.
As a result, iteration through tables typically doesn’t result in function calls for every iteration; the performance of iteration using generalized iteration, pairs and ipairs is comparable, so generalized iteration (without the use of pairs/ipairs) is recommended unless the code needs to be compatible with vanilla Lua or the specific semantics of ipairs (which stops at the first nil element) is required. Additionally, using generalized iteration avoids calling pairs when the loop starts which can be noticeable when the table is very short.
Iterating through array-like tables using for i=1,#t tends to be slightly slower because of extra cost incurred when reading elements from the table.

Optimized table length
Luau tables use a hybrid array/hash storage, like in Lua; in some sense “arrays” don’t truly exist and are an internal optimization, but some operations, notably #t and functions that depend on it, like table.insert, are defined by the Luau/Lua language to allow internal optimizations. Luau takes advantage of that fact.
Unlike Lua, Luau guarantees that the element at index #t is stored in the array part of the table. This can accelerate various table operations that use indices limited by #t, and this makes #t worst-case complexity O(logN), unlike Lua where the worst case complexity is O(N). This also accelerates computation of this value for small tables like { [1] = 1 } since we never need to look at the hash part.
The “default” implementation of #t in both Lua and Luau is a binary search. Luau uses a special branch-free (depending on the compiler…) implementation of the binary search which results in 50+% faster computation of table length when it needs to be computed from scratch.
Additionally, Luau can cache the length of the table and adjust it following operations like table.insert/table.remove; this means that in practice, #t is almost always a constant time operation.

Creating and modifying tables
Luau implements several optimizations for table creation. When creating object-like tables, it’s recommended to use table literals ({ ... }) and to specify all table fields in the literal in one go instead of assigning fields later; this triggers an optimization inspired by LuaJIT’s “table templates” and results in higher performance when creating objects. When creating array-like tables, if the maximum size of the table is known up front, it’s recommended to use table.create function which can create an empty table with preallocated storage, and optionally fill it with a given value.
When the exact table shape isn’t known, Luau compiler can still predict the table capacity required in case the table is initialized with an empty literal ({}) and filled with fields subsequently. For example, the following code creates a correctly sized table implicitly:

local v = {}
v.x = 1
v.y = 2
v.z = 3
return v

When appending elements to tables, it’s recommended to use table.insert (which is the fastest method to append an element to a table if the table size is not known). In cases when a table is filled sequentially, however, it can be more efficient to use a known index for insertion - together with preallocating tables using table.create this can result in much faster code, for example this is the fastest way to build a table of squares:

local t = table.create(N)

for i=1,N do
	t[i] = i * i
end

Native vector math
Luau uses tagged value storage - each value contains a type tag and the data that represents the value of a given type. Because of the need to store 64-bit double precision numbers and 64-bit pointers, we don’t use NaN tagging and have to pay the cost of 16 bytes per value.
We take advantage of this to provide a native value type that can store a 32-bit floating point vector with 3 components. This type is fundamental to game computations and as such it’s important to optimize the storage and the operations with that type - our VM implements first class support for all math operations and component manipulation, which essentially means we have native 3-wide SIMD support. For code that uses many vector values this results in significantly smaller GC pressure and significantly faster execution, and gives programmers a mechanism to hand-vectorize numeric code if need be.

Optimized upvalue storage
Lua implements upvalues as garbage collected objects that can point directly at the thread’s stack or, when the value leaves the stack frame (and is “closed”), store the value inside the object. This representation is necessary when upvalues are mutated, but inefficient when they aren’t - and 90% or more of upvalues aren’t mutated in typical Lua code. Luau takes advantage of this by reworking upvalue storage to prioritize immutable upvalues - capturing upvalues that don’t change doesn’t require extra allocations or upvalue closing, resulting in faster closure allocation, faster execution, faster garbage collection and faster upvalue access due to better memory locality.
Note that “immutable” in this case only refers to the variable itself - if the variable isn’t assigned to it can be captured by value, even if it’s a table that has its contents change.
When upvalues are mutable, they do require an extra allocated object; we carefully optimize the memory consumption and access cost for mutable upvalues to reduce the associated overhead.

Closure caching
With optimized upvalue storage, creating new closures (function objects) is more efficient but still requires allocating a new object every time. This can be problematic for cases when functions are passed to algorithms like table.sort or functions like pcall, as it results in excessive allocation traffic which then leads to more work for garbage collector.
To make closure creation cheaper, Luau compiler implements closure caching - when multiple executions of the same function expression are guaranteed to result in the function object that is semantically identical, the compiler may cache the closure and always return the same object. This changes the function identity which may affect code that uses function objects as table keys, but preserves the calling semantics - compiler will only do this if calling the original (cached) function behaves the same way as a newly created function would. The heuristics used for this optimization are subject to change; currently, the compiler will cache closures that have no upvalues, or all upvalues are immutable (see previous section) and are declared at the module scope, as the module scope is (almost always) evaluated only once.

Fast memory allocator
Similarly to LuaJIT, but unlike vanilla Lua, Luau implements a custom allocator that is highly specialized and tuned to the common allocation workloads we see. The allocator design is inspired by classic pool allocators as well as the excellent mimalloc, but through careful domain-specific tuning it beats all general purpose allocators we’ve tested, including rpmalloc, mimalloc, jemalloc, ptmalloc and tcmalloc.
This doesn’t mean that memory allocation in Luau is free - it’s carefully optimized, but it still carries a cost, and a high rate of allocations requires more work from the garbage collector. The garbage collector is incremental, so short of some edge cases this rarely results in visible GC pauses, but can impact the throughput since scripts will interrupt to perform “GC assists” (helping clean up the garbage). Thus for high performance Luau code it’s recommended to avoid allocating memory in tight loops, by avoiding temporary table and userdata creation.
In addition to a fast allocator, all frequently used structures in Luau have been optimized for memory consumption, especially on 64-bit platforms, compared to Lua 5.1 baseline. This helps to reduce heap memory footprint and improve performance in some cases by reducing the memory bandwidth impact of garbage collection.

Optimized libraries
While the best performing code in Luau spends most of the time in the interpreter, performance of the standard library functions is critical to some applications. In addition to specializing many small and simple functions using the builtin call mechanism, we spend extra care on optimizing all library functions and providing additional functions beyond the Lua standard library that help achieve good performance with idiomatic code.
Functions from the table library like insert, remove and move have been tuned for performance on array-like tables, achieving 3x and more performance compared to un-tuned versions, and Luau provides additional functions like table.create and table.find to achieve further speedup when applicable. Our implementation of table.sort is using introsort algorithm which results in guaranteed worst case NlogN complexity regardless of the input, and, together with the array-like specializations, helps achieve ~4x speedup on average.
For string library, we use a carefully tuned dynamic string buffer implementation; it is optimized for smaller strings to reduce garbage created during string manipulation, and for larger strings it allows to produce a large string without extra copies, especially in cases where the resulting size is known ahead of time. Additionally, functions like format have been tuned to avoid the overhead of sprintf where possible, resulting in further speedups.

Improved garbage collector pacing
Luau uses an incremental garbage collector which does a little bit of work every so often, and at no point does it stop the world to traverse the entire heap. The runtime will make sure that the collector runs interspersed with the program execution as the program allocates additional memory, which is known as “garbage collection assists”, and can also run in response to explicit garbage collection invocation via lua_gc. In interactive environments such as video game engines it’s possible, and even desirable, to request garbage collection every frame to make sure assists are minimized, since that allows scheduling the garbage collection to run concurrently with other engine processing that doesn’t involve script execution.
Inspired by excellent work by Austin Clements on Go’s garbage collector pacer, we’ve implemented a pacing algorithm that uses a proportional–integral–derivative controller to estimate internal garbage collector tunables to reach a target heap size, defined as a percentage of the live heap data (which is more intuitive and actionable than Lua 5.x “GC pause” setting). Luau runtime also estimates the allocation rate making it easy (given uniform allocation rates) to adjust the per-frame garbage collection requests to do most of the required GC work outside of script execution.

Reduced garbage collector pauses
While Luau uses an incremental garbage collector, once per each collector cycle it runs a so-called “atomic” step. While all other GC steps can do very little work by only looking at a few objects at a given time, which means that the collector can have arbitrarily short pauses, the “atomic” step needs to traverse some amount of data that, in some cases, may scale with the application heap. Since atomic step is indivisible, it can result in occasional pauses on the order of tens of milliseconds, which is problematic for interactive applications. We’ve implemented a series of optimizations to help reduce the atomic step.
Normally objects that have been modified after the GC marked them in an incremental mark phase need to be rescanned during atomic phase, so frequent modifications of existing tables may result in a slow atomic step. To address this, we run a “remark” step where we traverse objects that have been modified after being marked once more (incrementally); additionally, the write barrier that triggers for object modifications changes the transition logic during remark phase to reduce the probability that the object will need to be rescanned.
Another source of scalability challenges is coroutines. Writes to coroutine stacks don’t use a write barrier, since that’s prohibitively expensive as they are too frequent. This means that coroutine stacks need to be traversed during atomic step, so applications with many coroutines suffer large atomic pauses. To address this, we implement incremental marking of coroutines: marking a coroutine makes it “inactive” and resuming a coroutine (or pushing extra objects on the coroutine stack via C API) makes it “active”. Atomic step only needs to traverse active coroutines again, which reduces the cost of atomic step by effectively making coroutine collection incremental as well.
While large tables can be a problem for incremental GC in general since currently marking a single object is indivisible, large weak tables are a unique challenge because they also need to be processed during atomic phase, and the main use case for weak tables - object caches - may result in tables with large capacity but few live objects in long-running applications that exhibit bursts of activity. To address this, weak tables in Luau can be marked as “shrinkable” by including s as part of __mode string, which results in weak tables being resized to the optimal capacity during GC. This option may result in missing keys during table iteration if the table is resized while iteration is in progress and as such is only recommended for use in specific circumstances.

Optimized garbage collector sweeping
The incremental garbage collector in Luau runs three phases for each cycle: mark, atomic and sweep. Mark incrementally traverses all live objects, atomic finishes various operations that need to happen without mutator intervention (see previous section), and sweep traverses all objects in the heap, reclaiming memory used by dead objects and performing minor fixup for live objects. While objects allocated during the mark phase are traversed in the same cycle and thus may get reclaimed, objects allocated during the sweep phase are considered live. Because of this, the faster the sweep phase completes, the less garbage will accumulate; and, of course, the less time sweeping takes the less overhead there is from this phase of garbage collection on the process.
Since sweeping traverses the whole heap, we maximize the efficiency of this traversal by allocating garbage-collected objects of the same size in 16 KB pages, and traversing each page at a time, which is otherwise known as a paged sweeper. This ensures good locality of reference as consecutively swept objects are contiguous in memory, and allows us to spend no memory for each object on sweep-related data or allocation metadata, since paged sweeper doesn’t need to be able to free objects without knowing which page they are in. Compared to linked list based sweeping that Lua/LuaJIT implement, paged sweeper is 2-3x faster, and saves 16 bytes per object on 64-bit platforms.

Function inlining and loop unrolling
By default, the bytecode compiler performs a series of optimizations that result in faster execution of the code, but they preserve both execution semantics and debuggability. For example, a function call is compiled as a function call, which may be observable via debug.traceback; a loop is compiled as a loop, which may be observable via lua_getlocal. To help improve performance in cases where these restrictions can be relaxed, the bytecode compiler implements additional optimizations when optimization level 2 is enabled (which requires using -O2 switch when using Luau CLI), namely function inlining and loop unrolling.
Only loops with loop bounds known at compile time, such as for i=1,4 do, can be unrolled. The loop body must be simple enough for the optimization to be profitable; compiler uses heuristics to estimate the performance benefit and automatically decide if unrolling should be performed.
Only local functions (defined either as local function foo or local foo = function) can be inlined. The function body must be simple enough for the optimization to be profitable; compiler uses heuristics to estimate the performance benefit and automatically decide if each call to the function should be inlined instead. Additionally recursive invocations of a function can’t be inlined at this time, and inlining is completely disabled for modules that use getfenv/setfenv functions.
In both cases, in addition to removing the overhead associated with function calls or loop iteration, these optimizations can additionally benefit by enabling additional optimizations, such as constant folding of expressions dependent on loop iteration variable or constant function arguments, or using more efficient instructions for certain expressions when the inputs to these instructions are constants.

Globals

function assert<T>(value: T, message: string?): T

assert checks if the value is truthy; if it’s not (which means it’s false or nil), it raises an error. The error message can be customized with an optional parameter. Upon success the function returns the value argument.

function error(obj: any, level: number?)

error raises an error with the specified object. Note that errors don’t have to be strings, although they often are by convention; various error handling mechanisms like pcall preserve the error type. When level is specified, the error raised is turned into a string that contains call frame information for the caller at level level, where 1 refers to the function that called error. This can be useful to attribute the errors to callers, for example error("Expected a valid object", 2) highlights the caller of the function that called error instead of the function itself in the callstack.

function gcinfo(): number

gcinfo returns the total heap size in kilobytes, which includes bytecode objects, global tables as well as the script-allocated objects. Note that Luau uses an incremental garbage collector, and as such at any given point in time the heap may contain both reachable and unreachable objects. The number returned by gcinfo reflects the current heap consumption from the operating system perspective and can fluctuate over time as garbage collector frees objects.

function getfenv(target: (function | number)?): table

Returns the environment table for target function; when target is not a function, it must be a number corresponding to the caller stack index, where 1 means the function that calls getfenv, and the environment table is returned for the corresponding function from the call stack. When target is omitted it defaults to 1, so getfenv() returns the environment table for the calling function.

function getmetatable(obj: any): table?
Returns the metatable for the specified object; when object is not a table or a userdata, the returned metatable is shared between all objects of the same type. Note that when metatable is protected (has a __metatable key), the value corresponding to that key is returned instead and may not be a table.

function next<K, V>(t: { [K]: V }, i: K?): (K, V)?
Given the table t, returns the next key-value pair after i in the table traversal order, or nothing if i is the last key. When i is nil, returns the first key-value pair instead.

function newproxy(mt: boolean?): userdata
Creates a new untyped userdata object; when mt is true, the new object has an empty metatable that can be modified using getmetatable.

function print(args: ...any)
Prints all arguments to the standard output, using Tab as a separator.

function rawequal(a: any, b: any): boolean
Returns true iff a and b have the same type and point to the same object (for garbage collected types) or are equal (for value types).

function rawget<K, V>(t: { [K]: V }, k: K): V?
Performs a table lookup with index k and returns the resulting value, if present in the table, or nil. This operation bypasses metatables/__index.

function rawset<K, V>(t: { [K] : V }, k: K, v: V)
Assigns table field k to the value v. This operation bypasses metatables/__newindex.

function select<T>(i: string, args: ...T): number
function select<T>(i: number, args: ...T): ...T
When called with '#' as the first argument, returns the number of remaining parameters passed. Otherwise, returns the subset of parameters starting with the specified index. Index can be specified from the start of the arguments (using 1 as the first argument), or from the end (using -1 as the last argument).

function setfenv(target: function | number, env: table)
Changes the environment table for target function to env; when target is not a function, it must be a number corresponding to the caller stack index, where 1 means the function that calls setfenv, and the environment table is returned for the corresponding function from the call stack.

function setmetatable(t: table, mt: table?)
Changes metatable for the given table. Note that unlike getmetatable, this function only works on tables. If the table already has a protected metatable (has a __metatable field), this function errors.

function tonumber(s: string, base: number?): number?
Converts the input string to the number in base base (default 10) and returns the resulting number. If the conversion fails (that is, if the input string doesn’t represent a valid number in the specified base), returns nil instead.

function tostring(obj: any): string
Converts the input object to string and returns the result. If the object has a metatable with __tostring field, that method is called to perform the conversion.

function type(obj: any): string
Returns the type of the object, which is one of "nil", "boolean", "number", "vector", "string", "table", "function", "userdata", "thread", or "buffer".

function typeof(obj: any): string
Returns the type of the object; for userdata objects that have a metatable with the __type field and are defined by the host (not newproxy), returns the value for that key. For custom userdata objects, such as ones returned by newproxy, this function returns "userdata" to make sure host-defined types can not be spoofed.

function ipairs(t: table): <iterator>
Returns the triple (generator, state, nil) that can be used to traverse the table using a for loop. The traversal results in key-value pairs for the numeric portion of the table; key starts from 1 and increases by 1 on each iteration. The traversal terminates when reaching the first nil value (so ipairs can’t be used to traverse array-like tables with holes).

function pairs(t: table): <iterator>
Returns the triple (generator, state, nil) that can be used to traverse the table using a for loop. The traversal results in key-value pairs for all keys in the table, numeric and otherwise, but doesn’t have a defined order.

function pcall(f: function, args: ...any): (boolean, ...any)
Calls function f with parameters args. If the function succeeds, returns true followed by all return values of f. If the function raises an error, returns false followed by the error object. Note that f can yield, which results in the entire coroutine yielding as well.

function xpcall(f: function, e: function, args: ...any): (boolean, ...any)
Calls function f with parameters args. If the function succeeds, returns true followed by all return values of f. If the function raises an error, calls e with the error object as an argument, and returns false followed by all return values of e. Note that f can yield, which results in the entire coroutine yielding as well. e can neither yield nor error - if it does raise an error, xpcall returns with false followed by a special error message.

function unpack<V>(a: {V}, f: number?, t: number?): ...V
Returns all values of a with indices in [f..t] range. f defaults to 1 and t defaults to #a. Note that this is equivalent to table.unpack.

Math
This library is an interface to the standard C math library, providing all of its functions inside the math table.

function math.abs(n: number): number
Returns the absolute value of n. Returns NaN if the input is NaN.

function math.acos(n: number): number
Returns the arc cosine of n, expressed in radians. Returns a value in [0, pi] range. Returns NaN if the input is not in [-1, +1] range.

function math.asin(n: number): number
Returns the arc sine of n, expressed in radians. Returns a value in [-pi/2, +pi/2] range. Returns NaN if the input is not in [-1, +1] range.

function math.atan2(y: number, x: number): number
Returns the arc tangent of y/x, expressed in radians. The function takes into account the sign of both arguments in order to determine the quadrant. Returns a value in [-pi, pi] range.

function math.atan(n: number): number
Returns the arc tangent of n, expressed in radians. Returns a value in [-pi/2, pi-2] range.

function math.ceil(n: number): number
Rounds n upwards to the next integer boundary.

function math.cosh(n: number): number
Returns the hyperbolic cosine of n.

function math.cos(n: number): number
Returns the cosine of n, which is an angle in radians. Returns a value in [0, 1] range.

function math.deg(n: number): number
Converts n from radians to degrees and returns the result.

function math.exp(n: number): number
Returns the base-e exponent of n, that is e^n.

function math.floor(n: number): number
Rounds n downwards to previous integer boundary.

function math.fmod(x: number, y: number): number
Returns the remainder of x modulo y, rounded towards zero. Returns NaN if y is zero.

function math.frexp(n: number): (number, number)
Splits the number into a significand (a number in [-1, +1] range) and binary exponent such that n = s * 2^e, and returns s, e.

function math.ldexp(s: number, e: number): number
Given the significand and a binary exponent, returns a number s * 2^e.

function math.lerp(a: number, b: number, t: number): number
Linearly interpolated between number value a and b using factor t, generally returning the result of a + (b - a) * t. When t is exactly 1, the value of b will be returned instead to ensure that when t is on the interval [0, 1], the result of lerp will be on the interval [a, b].

function math.log10(n: number): number
Returns base-10 logarithm of the input number. Returns NaN if the input is negative, and negative infinity if the input is 0. Equivalent to math.log(n, 10).

function math.log(n: number, base: number?): number
Returns logarithm of the input number in the specified base; base defaults to e. Returns NaN if the input is negative, and negative infinity if the input is 0.

function math.max(list: ...number): number
Returns the maximum number of the input arguments. The function requires at least one input and will error if zero parameters are passed. If one of the inputs is a NaN, the result may or may not be a NaN.

function math.min(list: ...number): number
Returns the minimum number of the input arguments. The function requires at least one input and will error if zero parameters are passed. If one of the inputs is a NaN, the result may or may not be a NaN.

function math.modf(n: number): (number, number)
Returns the integer and fractional part of the input number. Both the integer and fractional part have the same sign as the input number, e.g. math.modf(-1.5) returns -1, -0.5.

function math.pow(x: number, y: number): number
Returns x raised to the power of y.

function math.rad(n: number): number
Converts n from degrees to radians and returns the result.

function math.random(): number
function math.random(n: number): number
function math.random(min: number, max: number): number
Returns a random number using the global random number generator. A zero-argument version returns a number in [0, 1] range. A one-argument version returns a number in [1, n] range. A two-argument version returns a number in [min, max] range. The input arguments are truncated to integers, so math.random(1.5) always returns 1.

function math.randomseed(seed: number)
Reseeds the global random number generator; subsequent calls to math.random will generate a deterministic sequence of numbers that only depends on seed.

function math.sinh(n: number): number
Returns a hyperbolic sine of n.

function math.sin(n: number): number
Returns the sine of n, which is an angle in radians. Returns a value in [0, 1] range.

function math.sqrt(n: number): number
Returns the square root of n. Returns NaN if the input is negative.

function math.tanh(n: number): number
Returns the hyperbolic tangent of n.

function math.tan(n: number): number
Returns the tangent of n, which is an angle in radians.

function math.noise(x: number, y: number?, z: number?): number
Returns 3D Perlin noise value for the point (x, y, z) (y and z default to zero if absent). Returns a value in [-1, 1] range.

function math.clamp(n: number, min: number, max: number): number
Returns n if the number is in [min, max] range; otherwise, returns min when n < min, and max otherwise. If n is NaN, may or may not return NaN. The function errors if min > max.

function math.sign(n: number): number
Returns -1 if n is negative, 1 if n is positive, and 0 if n is zero or NaN.

function math.round(n: number): number
Rounds n to the nearest integer boundary. If n is exactly halfway between two integers, rounds n away from 0.

Table
This library provides generic functions for table/array manipulation, providing all its functions inside the global table variable.

function table.concat(a: {string}, sep: string?, f: number?, t: number?): string
Concatenate all elements of a with indices in range [f..t] together, using sep as a separator if present. f defaults to 1 and t defaults to #a.

function table.foreach<K, V, R>(t: { [K]: V }, f: (K, V) -> R?): R?
Iterates over all elements of the table in unspecified order; for each key-value pair, calls f and returns the result of f if it’s non-nil. If all invocations of f returned nil, returns no values. This function has been deprecated and is not recommended for use in new code; use for loop instead.

function table.foreachi<V, R>(t: {V}, f: (number, V) -> R?): R?
Iterates over numeric keys of the table in [1..#t] range in order; for each key-value pair, calls f and returns the result of f if it’s non-nil. If all invocations of f returned nil, returns no values. This function has been deprecated and is not recommended for use in new code; use for loop instead.

function table.getn<V>(t: {V}): number
Returns the length of table t. This function has been deprecated and is not recommended for use in new code; use #t instead.

function table.maxn<V>(t: {V}): number
Returns the maximum numeric key of table t, or zero if the table doesn’t have numeric keys.

function table.insert<V>(t: {V}, v: V)
function table.insert<V>(t: {V}, i: number, v: V)
When using a two-argument version, appends the value to the array portion of the table (equivalent to t[#t+1] = v). When using a three-argument version, inserts the value at index i and shifts values at indices after that by 1. i should be in [1..#t] range.

function table.remove<V>(t: {V}, i: number?): V?
Removes element i from the table and shifts values at indices after that by 1. If i is not specified, removes the last element of the table. i should be in [1..#t] range. Returns the value of the removed element, or nil if no element was removed (e.g. table was empty).

function table.sort<V>(t: {V}, f: ((V, V) -> boolean)?)
Sorts the table t in ascending order, using f as a comparison predicate: f should return true iff the first parameter should be before the second parameter in the resulting table. When f is not specified, builtin less-than comparison is used instead. The comparison predicate must establish a strict weak ordering - sort results are undefined otherwise.

function table.pack<V>(args: ...V): { [number]: V, n: number }
Returns a table that consists of all input arguments as array elements, and n field that is set to the number of inputs.

function table.unpack<V>(a: {V}, f: number?, t: number?): ...V
Returns all values of a with indices in [f..t] range. f defaults to 1 and t defaults to #a. Note that if you want to unpack varargs packed with table.pack you have to specify the index fields because table.unpack doesn’t automatically use the n field that table.pack creates. Example usage for packed varargs: table.unpack(args, 1, args.n)

function table.move<V>(a: {V}, f: number, t: number, d: number, tt: {V}?)
Copies elements in range [f..t] from table a to table tt if specified and a otherwise, starting from the index d.

function table.create<V>(n: number, v: V?): {V}
Creates a table with n elements; all of them (range [1..n]) are set to v. When v is nil or omitted, the returned table is empty but has preallocated space for n elements which can make subsequent insertions faster. Note that preallocation is only performed for the array portion of the table - using table.create on dictionaries is counter-productive.

function table.find<V>(t: {V}, v: V, init: number?): number?
Find the first element in the table that is equal to v and returns its index; the traversal stops at the first nil. If the element is not found, nil is returned instead. The traversal starts at index init if specified, otherwise 1.

function table.clear(t: table)
Removes all elements from the table while preserving the table capacity, so future assignments don’t need to reallocate space.

function table.freeze(t: table): table
Given a non-frozen table, freezes it such that all subsequent attempts to modify the table or assign its metatable raise an error. If the input table is already frozen or has a protected metatable, the function raises an error; otherwise it returns the input table. Note that the table is frozen in-place and is not being copied. Additionally, only t is frozen, and keys/values/metatable of t don’t change their state and need to be frozen separately if desired.

function table.isfrozen(t: table): boolean
Returns true iff the input table is frozen.

function table.clone(t: table): table
Returns a copy of the input table that has the same metatable, same keys and values, and is not frozen even if t was. The copy is shallow: implementing a deep recursive copy automatically is challenging, and often only certain keys need to be cloned recursively which can be done after the initial clone by modifying the resulting table.

String
The string library provides generic functions to manipulate strings, such as to extract substrings or match patterns.

function string.byte(s: string, f: number?, t: number?): ...number
Returns the numeric code of every byte in the input string with indices in range [f..t]. f defaults to 1 and t defaults to f, so a two-argument version of this function returns a single number. If the function is called with a single argument and the argument is out of range, the function returns no values.

function string.char(args: ...number): string
Returns the string that contains a byte for every input number; all inputs must be integers in [0..255] range.

function string.find(s: string, p: string, init: number?, plain: boolean?): (number?, number?, ...string)
Tries to find an instance of pattern p in the string s, starting from position init (defaults to 1). When plain is true, the search is using raw (case-sensitive) string equality, otherwise p should be a string pattern. If a match is found, returns the position of the match and the length of the match, followed by the pattern captures; otherwise returns nil.

function string.format(s: string, args: ...any): string
Returns a formatted version of the input arguments using a printf-style format string s. The following format characters are supported:

c: expects an integer number and produces a character with the corresponding character code

d, i, u: expects an integer number and produces the decimal representation of that number

o: expects an integer number and produces the octal representation of that number

x, X: expects an integer number and produces the hexadecimal representation of that number, using lower case or upper case hexadecimal characters

e, E, f, g, G: expects a number and produces the floating point representation of that number, using scientific or decimal representation

q: expects a string and produces the same string quoted using double quotation marks, with escaped special characters if necessary

s: expects a string and produces the same string verbatim

The formats support modifiers -, +, space, # and 0, as well as field width and precision modifiers - with the exception of *.

function string.gmatch(s: string, p: string): <iterator>
Produces an iterator function that, when called repeatedly explicitly or via for loop, produces matches of string s with string pattern p. For every match, the captures within the pattern are returned if present (if a pattern has no captures, the entire matching substring is returned instead).

function string.gsub(s: string, p: string, f: function | table | string, maxs: number?): (string, number)
For every match of string pattern p in s, replace the match according to f. The substitutions stop after the limit of maxs, and the function returns the resulting string followed by the number of substitutions.

When f is a string, the substitution uses the string as a replacement. When f is a table, the substitution uses the table element with key corresponding to the first pattern capture, if present, and entire match otherwise. Finally, when f is a function, the substitution uses the result of calling f with call pattern captures, or entire matching substring if no captures are present.

function string.len(s: string): number
Returns the number of bytes in the string (equivalent to #s).

function string.lower(s: string): string
Returns a string where each byte corresponds to the lower-case ASCII version of the input byte in the source string.

function string.match(s: string, p: string, init: number?): ...string?
Tries to find an instance of pattern p in the string s, starting from position init (defaults to 1). p should be a string pattern. If a match is found, returns all pattern captures, or entire matching substring if no captures are present, otherwise returns nil.

function string.rep(s: string, n: number): string
Returns the input string s repeated n times. Returns an empty string if n is zero or negative.

function string.reverse(s: string): string
Returns the string with the order of bytes reversed compared to the original. Note that this only works if the input is a binary or ASCII string.

function string.sub(s: string, f: number, t: number?): string
Returns a substring of the input string with the byte range [f..t]; t defaults to #s, so a two-argument version returns a string suffix.

function string.upper(s: string): string
Returns a string where each byte corresponds to the upper-case ASCII version of the input byte in the source string.

function string.split(s: string, sep: string?): {string}
Splits the input string using sep as a separator (defaults to ",") and returns the resulting substrings. If separator is empty, the input string is split into separate one-byte strings.

function string.pack(f: string, args: ...any): string
Given a pack format string, encodes all input parameters according to the packing format and returns the resulting string. Note that Luau uses fixed sizes for all types that have platform-dependent size in Lua 5.x: short is 16 bit, long is 64 bit, integer is 32-bit and size_t is 32 bit for the purpose of string packing.

function string.packsize(f: string): number
Given a pack format string, returns the size of the resulting packed representation. The pack format can’t use variable-length format specifiers. Note that Luau uses fixed sizes for all types that have platform-dependent size in Lua 5.x: short is 16 bit, long is 64 bit, integer is 32-bit and size_t is 32 bit for the purpose of string packing.

function string.unpack(f: string, s: string): ...any
Given a pack format string, decodes the input string according to the packing format and returns all resulting values. Note that Luau uses fixed sizes for all types that have platform-dependent size in Lua 5.x: short is 16 bit, long is 64 bit, integer is 32-bit and size_t is 32 bit for the purpose of string packing.

Coroutine
A coroutine is used to perform multiple tasks at the same time from within the same script.

function coroutine.create(f: function): thread
Returns a new coroutine that, when resumed, will run function f.

function coroutine.running(): thread?
Returns the currently running coroutine, or nil if the code is running in the main coroutine (depending on the host environment setup, main coroutine may never be used for running code).

function coroutine.status(co: thread): string
Returns the status of the coroutine, which can be "running", "suspended", "normal" or "dead". Dead coroutines have finished their execution and can not be resumed, but their state can still be inspected as they are not dead from the garbage collector point of view.

function coroutine.wrap(f: function): function
Creates a new coroutine and returns a function that, when called, resumes the coroutine and passes all arguments along to the suspension point. When the coroutine yields or finishes, the wrapped function returns with all values returned at the suspension point.

function coroutine.yield(args: ...any): ...any
Yields the currently running coroutine and passes all arguments along to the code that resumed the coroutine. The coroutine becomes suspended; when the coroutine is resumed again, the resumption arguments will be forwarded to yield which will behave as if it returned all of them.

function coroutine.isyieldable(): boolean
Returns true iff the currently running coroutine can yield. Yielding is prohibited when running inside metamethods like __index or C functions like table.foreach callback, with the exception of pcall/xpcall.

function coroutine.resume(co: thread, args: ...any): (boolean, ...any)
Resumes the coroutine and passes the arguments along to the suspension point. When the coroutine yields or finishes, returns true and all values returned at the suspension point. If an error is raised during coroutine resumption, this function returns false and the error object, similarly to pcall.

function coroutine.close(co: thread): (boolean, any?)
Closes the coroutine which puts coroutine in the dead state. The coroutine must be dead or suspended - in particular it can’t be currently running. If the coroutine that’s being closed was in an error state, returns false along with an error object; otherwise returns true. After closing, the coroutine can’t be resumed and the coroutine stack becomes empty.

Bit32
This library provides functions to perform bitwise operations.

All functions in the bit32 library treat input numbers as 32-bit unsigned integers in [0..4294967295] range. The bit positions start at 0 where 0 corresponds to the least significant bit.

function bit32.arshift(n: number, i: number): number
Shifts n by i bits to the right (if i is negative, a left shift is performed instead). The most significant bit of n is propagated during the shift. When i is larger than 31, returns an integer with all bits set to the sign bit of n. When i is smaller than -31, 0 is returned.

function bit32.band(args: ...number): number
Performs a bitwise and of all input numbers and returns the result. If the function is called with no arguments, an integer with all bits set to 1 is returned.

function bit32.bnot(n: number): number
Returns a bitwise negation of the input number.

function bit32.bor(args: ...number): number
Performs a bitwise or of all input numbers and returns the result. If the function is called with no arguments, zero is returned.

function bit32.bxor(args: ...number): number
Performs a bitwise xor (exclusive or) of all input numbers and returns the result. If the function is called with no arguments, zero is returned.

function bit32.btest(args: ...number): boolean
Perform a bitwise and of all input numbers, and return true iff the result is not 0. If the function is called with no arguments, true is returned.

function bit32.extract(n: number, f: number, w: number?): number
Extracts bits of n at position f with a width of w, and returns the resulting integer. w defaults to 1, so a two-argument version of extract returns the bit value at position f. Bits are indexed starting at 0. Errors if f and f+w-1 are not between 0 and 31.

function bit32.lrotate(n: number, i: number): number
Rotates n to the left by i bits (if i is negative, a right rotate is performed instead); the bits that are shifted past the bit width are shifted back from the right.

function bit32.lshift(n: number, i: number): number
Shifts n to the left by i bits (if i is negative, a right shift is performed instead). When i is outside of [-31..31] range, returns 0.

function bit32.replace(n: number, r: number, f: number, w: number?): number
Replaces bits of n at position f and width w with r, and returns the resulting integer. w defaults to 1, so a three-argument version of replace changes one bit at position f to r (which should be 0 or 1) and returns the result. Bits are indexed starting at 0. Errors if f and f+w-1 are not between 0 and 31.

function bit32.rrotate(n: number, i: number): number
Rotates n to the right by i bits (if i is negative, a left rotate is performed instead); the bits that are shifted past the bit width are shifted back from the left.

function bit32.rshift(n: number, i: number): number
Shifts n to the right by i bits (if i is negative, a left shift is performed instead). When i is outside of [-31..31] range, returns 0.

function bit32.countlz(n: number): number
Returns the number of consecutive zero bits in the 32-bit representation of n starting from the left-most (most significant) bit. Returns 32 if n is zero.

function bit32.countrz(n: number): number
Returns the number of consecutive zero bits in the 32-bit representation of n starting from the right-most (least significant) bit. Returns 32 if n is zero.

function bit32.byteswap(n: number): number
Returns n with the order of the bytes swapped.

UTF8
This library provides basic support for UTF-8 encoding. It does not provide any support for Unicode other than the handling of the encoding.

Strings in Luau can contain arbitrary bytes; however, in many applications strings representing text contain UTF8 encoded data by convention, that can be inspected and manipulated using utf8 library.

function utf8.offset(s: string, n: number, i: number?): number?
Returns the byte offset of the Unicode codepoint number n in the string, starting from the byte position i. When the character is not found, returns nil instead.

function utf8.codepoint(s: string, i: number?, j: number?): ...number
Returns a number for each Unicode codepoint in the string with the starting byte offset in [i..j] range. i defaults to 1 and j defaults to i, so a two-argument version of this function returns the Unicode codepoint that starts at byte offset i.

function utf8.char(args: ...number): string
Creates a string by concatenating Unicode codepoints for each input number.

function utf8.len(s: string, i: number?, j: number?): number?
Returns the number of Unicode codepoints with the starting byte offset in [i..j] range, or nil followed by the first invalid byte position if the input string is malformed. i defaults to 1 and j defaults to #s, so utf8.len(s) returns the number of Unicode codepoints in string s or nil if the string is malformed.

function utf8.codes(s: string): <iterator>
Returns an iterator that, when used in for loop, produces the byte offset and the codepoint for each Unicode codepoints that s consists of.

OS
This library currently serves the purpose of providing information about the system time under the UTC format.

function os.clock(): number
Returns a high-precision timestamp (in seconds) that doesn’t have a defined baseline, but can be used to measure duration with sub-microsecond precision.

function os.date(s: string?, t: number?): table | string
Returns the table or string representation of the time specified as t (defaults to current time) according to s format string.

When s starts with !, the result uses UTC, otherwise it uses the current timezone.

If s is equal to *t (or !*t), a table representation of the date is returned, with keys sec/min/hour for the time (using 24-hour clock), day/month/year for the date, wday for week day (1..7), yday for year day (1..366) and isdst indicating whether the timezone is currently using daylight savings.

Otherwise, s is interpreted as a date format string, with the valid specifiers including any of aAbBcdHIjmMpSUwWxXyYzZ or %. s defaults to "%c" so os.date() returns the human-readable representation of the current date in local timezone.

function os.difftime(a: number, b: number): number
Calculates the difference in seconds between a and b; provided for compatibility only. Please use a - b instead.

function os.time(t: table?): number
When called without arguments, returns the current date/time as a Unix timestamp. When called with an argument, expects it to be a table that contains sec/min/hour/day/month/year keys and returns the Unix timestamp of the specified date/time in UTC.

Debug
Provides a few basic functions for debugging code in Roblox. Unlike the debug library found in Lua natively, this version has been heavily sandboxed.

function debug.info(co: thread, level: number, s: string): ...any
function debug.info(level: number, s: string): ...any
function debug.info(f: function, s: string): ...any
Given a stack frame or a function, and a string that specifies the requested information, returns the information about the stack frame or function.

Each character of s results in additional values being returned in the same order as the characters appear in the string:

s returns source path for the function

l returns the line number for the stack frame or the line where the function is defined when inspecting a function object

n returns the name of the function, or an empty string if the name is not known

f returns the function object itself

a returns the number of arguments that the function expects followed by a boolean indicating whether the function is variadic or not

For example, debug.info(2, "sln") returns source file, current line and function name for the caller of the current function.

function debug.traceback(co: thread, msg: string?, level: number?): string
function debug.traceback(msg: string?, level: number?): string
Produces a stringified callstack of the given thread, or the current thread, starting with level level. If msg is specified, then the resulting callstack includes the string before the callstack output, separated with a newline. The format of the callstack is human-readable and subject to change.

Buffer
Buffer is intended to be used a low-level binary data storage structure, replacing the uses of string.pack() and string.unpack().

Buffer is an object that represents a fixed-size mutable block of memory.

All operations on a buffer are provided using the ‘buffer’ library functions.

Many of the functions accept an offset in bytes from the start of the buffer. Offset of 0 from the start of the buffer memory block accesses the first byte.

All offsets, counts and sizes should be non-negative integer numbers.

If the bytes that are accessed by any read or write operation are outside the buffer memory, an error is thrown.

function buffer.create(size: number): buffer
Creates a buffer of the requested size with all bytes initialized to 0.

Size limit is 1GB or 1,073,741,824 bytes.

function buffer.fromstring(str: string): buffer
Creates a buffer initialized to the contents of the string.

The size of the buffer equals to the length of the string.

function buffer.tostring(b: buffer): string
Returns the buffer data as a string.

function buffer.len(b: buffer): number
Returns the size of the buffer in bytes.

function buffer.readi8(b: buffer, offset: number): number
function buffer.readu8(b: buffer, offset: number): number
function buffer.readi16(b: buffer, offset: number): number
function buffer.readu16(b: buffer, offset: number): number
function buffer.readi32(b: buffer, offset: number): number
function buffer.readu32(b: buffer, offset: number): number
function buffer.readf32(b: buffer, offset: number): number
function buffer.readf64(b: buffer, offset: number): number
Used to read the data from the buffer by reinterpreting bytes at the offset as the type in the argument and converting it into a number.

Available types:

Function
Type
Range
readi8

signed 8-bit integer

[-128, 127]

readu8

unsigned 8-bit integer

[0, 255]

readi16

signed 16-bit integer

[-32,768, 32,767]

readu16

unsigned 16-bit integer

[0, 65,535]

readi32

signed 32-bit integer

[-2,147,483,648, 2,147,483,647]

readu32

unsigned 32-bit integer

[0, 4,294,967,295]

readf32

32-bit floating-point number

Single-precision IEEE 754 number

readf64

64-bit floating-point number

Double-precision IEEE 754 number

Floating-point numbers are read and written using a format specified by IEEE 754.

If a floating-point value matches any of bit patterns that represent a NaN (not a number), returned value might be converted to a different quiet NaN representation.

Read and write operations use the little endian byte order.

Integer numbers are read and written using two’s complement representation.

function buffer.writei8(b: buffer, offset: number, value: number): ()
function buffer.writeu8(b: buffer, offset: number, value: number): ()
function buffer.writei16(b: buffer, offset: number, value: number): ()
function buffer.writeu16(b: buffer, offset: number, value: number): ()
function buffer.writei32(b: buffer, offset: number, value: number): ()
function buffer.writeu32(b: buffer, offset: number, value: number): ()
function buffer.writef32(b: buffer, offset: number, value: number): ()
function buffer.writef64(b: buffer, offset: number, value: number): ()
Used to write data to the buffer by converting the number into the type in the argument and reinterpreting it as individual bytes.

Ranges of acceptable values can be seen in the table above.

When writing integers, the number is converted using bit32 library rules.

Values that are out-of-range will take less significant bits of the full number. For example, writing 43,981 (0xabcd) using writei8 function will take 0xcd and interpret it as an 8-bit signed number -51. It is still recommended to keep all numbers in range of the target type.

Results of converting special number values (inf/nan) to integers are platform-specific.

function buffer.readstring(b: buffer, offset: number, count: number): string
Used to read a string of length ‘count’ from the buffer at specified offset.

function buffer.writestring(b: buffer, offset: number, value: string, count: number?): ()
Used to write data from a string into the buffer at a specified offset.

If an optional ‘count’ is specified, only ‘count’ bytes are taken from the string.

Count cannot be larger than the string length.


function buffer.copy(target: buffer, targetOffset: number, source: buffer, sourceOffset: number?, count: number?): () 
Copy ‘count’ bytes from ‘source’ starting at offset ‘sourceOffset’ into the ‘target’ at ‘targetOffset’.

It is possible for ‘source’ and ‘target’ to be the same. Copying an overlapping region inside the same buffer acts as if the source region is copied into a temporary buffer and then that buffer is copied over to the target.

If ‘sourceOffset’ is nil or is omitted, it defaults to 0.

If ‘count’ is ‘nil’ or is omitted, the whole ‘source’ data starting from ‘sourceOffset’ is copied.

function buffer.fill(b: buffer, offset: number, value: number, count: number?): ()
Sets the ‘count’ bytes in the buffer starting at the specified ‘offset’ to the ‘value’.

If ‘count’ is ‘nil’ or is omitted, all bytes from the specified offset until the end of the buffer are set.

Vector
This library implements functionality for the vector type in addition to the built-in primitive operator support.

Default configuration uses vectors with 3 components (x, y, and z). If the 4-wide mode is enabled by setting the LUA_VECTOR_SIZE VM configuration to 4, vectors get an additional w component.

Individual vector components can be accessed using the fields x or X, y or Y, z or Z, and w or W in 4-wide mode. Since vector values are immutable, writes to individual components are not supported.

vector.zero
vector.one
Constant vectors with all components set to 0 and 1 respectively. Includes the fourth component in 4-wide mode.

vector.create(x: number, y: number, z: number): vector
vector.create(x: number, y: number, z: number, w: number): vector
Creates a new vector with the given component values. The first constructor sets the fourth (w) component to 0.0 in 4-wide mode.

vector.magnitude(vec: vector): number
Calculates the magnitude of a given vector. Includes the fourth component in 4-wide mode.

vector.normalize(vec: vector): vector
Computes the normalized version (unit vector) of a given vector. Includes the fourth component in 4-wide mode.

vector.cross(vec1: vector, vec2: vector): vector
Computes the cross product of two vectors. Ignores the fourth component in 4-wide mode and returns the 3-dimensional cross product.

vector.dot(vec1: vector, vec2: vector): number
Computes the dot product of two vectors. Includes the fourth component in 4-wide mode.

vector.angle(vec1: vector, vec2: vector, axis: vector?): number
Computes the angle between two vectors in radians. The axis, if specified, is used to determine the sign of the angle. Ignores the fourth component in 4-wide mode and returns the 3-dimensional angle.

vector.floor(vec: vector): vector
Applies math.floor to every component of the input vector. Includes the fourth component in 4-wide mode.

vector.ceil(vec: vector): vector
Applies math.ceil to every component of the input vector. Includes the fourth component in 4-wide mode.

vector.abs(vec: vector): vector
Applies math.abs to every component of the input vector. Includes the fourth component in 4-wide mode.

vector.sign(vec: vector): vector
Applies math.sign to every component of the input vector. Includes the fourth component in 4-wide mode.

vector.clamp(vec: vector, min: vector, max: vector): vector
Applies math.clamp to every component of the input vector. Includes the fourth component in 4-wide mode.

vector.max(...: vector): vector
Applies math.max to the corresponding components of the input vectors. Includes the fourth component in 4-wide mode. Equivalent to vector.create(math.max((...).x), math.max((...).y), math.max((...).z), math.max((...).w)).

vector.min(...: vector): vector
Applies math.min to the corresponding components of the input vectors. Includes the fourth component in 4-wide mode. Equivalent to vector.create(math.min((...).x), math.min((...).y), math.min((...).z), math.min((...).w)).

Explorer
Severe implements DEX, which is a tool that allows you to view the game's structure, it works very similar to Roblox Studio's explorer, or Dark Dex v4. The main difference, is that as of now 05/25/25, we do not allow you to view properties of instances, or copy their path (you will have to do that manually) although it is planned in future.

Usage
The first instance in the hierarchy, is the DataModel, it hosts all services, and all objects. It will usually be named after the game. You can click objects with an arrow to reveal their children, objects with gray dot do not have any children.

Charting
After finding an object, for this example it will be DataModel > Workspace > Pond: Model you will need to type out the path, as of currently, Severe supports Roblox Luau annotations, which means the path will be: workspace:FindFirstChild("Pond") 

This isn't the best code practice, as using findfirstchild(Workspace, "Pond") is about 1.6x faster, due to the fact that the Roblox Luau annotation implementation is written in Luau (in the initial script), and not in the native C.

Challenge
Join Fencing, and chart the path to DataModel > Workspace > Base: Part 

Memory Viewer
Severe implements a powerful tool to view memory state of objects. You can use it to implement features that weren't in Severe before, for example, attributes.

Buttons
Resume/Pause: pause/resume the viewer.
8 bytes/4 bytes: change the data size.
Find Value: search for value on the current page.
Previous/Next: to navigate between the previous, and next page.
Unsafe: toggle for unsafe view mode.

Usage
To find the memory pointer required to use the tool, go into DEX, and press "Expose Memory Pointers". Next click "copy" button next to object you're interested in, and paste in the copied value into "Enter Memory Pointer" textbox. Valid memory pointers should start with 0x and be encoded in hex.

After opening, you will be greeted with an UI like this:


Where the pink 0x8 is, signifies an offset. Do note that offsets aren't permanent, there's a possibility of them updating after the game updates.

The gray 0x12c287c7a30 signifies the address that the qword points to (in this case, the qword is 1289169435184, which when converted to hex, is 12C287C7A30).

The blue text RBX:DataModel is the string, and the white text (dword, qword, double, float) below it are data types, with their respective values.

Example
Create a private server in Desync Playground, as it allows you to run Dark Dex without an executor, after attaching Severe, press the script icon in the bottom-left corner. After the menu loads, press the hamburger icon, and search up "Dex Explorer V4", click on it and press the green play icon.

Once you see the menu, navigate into DataModel > Workspace and find your character model (it should be named after your player name). Find Head: Part and click on it to reveal its properties, and find Transparency 

Open Severe, and find the memory pointer for your head (should be similar as before), and enter that into the memory viewer.

Since transparency is designed to be a 0-1 unsigned decimal, you can safely presume it to be a float value. Now to proceed, set Transparency to a number, for example: 6677, navigate back to the memory viewer, and press the "Find Value" button, and search for your value (in this case, 6677), and for the type, type in "float", now it's gonna search for your value, and optimally you should see your value in the viewer similar to this:


Now, you know 0xf8 is the offset for the Transparency property, now to make it into a script you will need to find it's path, with either the Roblox Luau annotation:

local Players = game:GetService("Players")
local LocalPlayer = Players.localPlayer
local Character = LocalPlayer.Character
local Head = Character:FindFirstChild("Head")

Head:SetMemoryValue(0xf8, "float", 1) -- To make it transparent.
Or, using the recommended annotation:

local client = getlocalplayer()
local character = getcharacter(client)

setmemoryvalue(character, 0xf8, "float", 1) -- To make it transparent.
Challenge
Using the same game, and the same method, find JumpPower property.

JumpPower is designed to be stored as a signed decimal, so it is safe to assume it's a float.

Severe Annotations
Functions
Player
getlocalplayer

function getlocalplayer(): (userdata)
getcharacter

function getcharacter(player: userdata): (userdata)
getuserid

function getuserid(player: userdata): (number)
getdisplayname

function getdisplayname(player: userdata): (string)
getteam

function getteam(player: userdata): (userdata)
getping

function getping(): (number)
Instance
destroy

function destroy(object: userdata): ()
getchildren

function getchildren(object: userdata): { userdata }
getdescendants

function getdescendants(object: userdata): { userdata }
waitforchild

function waitforchild(object: userdata, name: string, timeout: number): (userdata)
findfirstancestorofclass

function findfirstancestorofclass(object: userdata, class: string): (userdata)
findfirstancestor

function findfirstancestor(object: userdata, name: string): (userdata)
findfirstdescendant

function findfirstdescendant(object: userdata, name: string): (userdata)
findfirstchildofclass

function findfirstchildchildofclass(object: userdata, class: string): (userdata)
findfirstchild

function findfirstchild(object: userdata, name: string): (userdata)
getclassname

function getclassname(object: userdata): (string)
getname

function getname(object: userdata): (string)
getparent

function getparent(object: userdata): (userdata)
isancestorof

function isancestorof(object: userdata): (boolean)
isdescendantof

function isdescendantof(object: userdata): (boolean)
Value
The object's class name must contain "Value" in order to use this.

getvalue

function getvalue(object: userdata): (any)
setvalue

function setvalue(object: userdata, value: any)

Luau Annotations
Methods
ServiceProvider
GetService

function game:GetService(name: string): (Instance)
Camera
WorldToScreenPoint

function Camera:WorldToScreenPoint(world: vector): (vector, boolean)
Instance
FindFirstChild

function Instance:FindFirstChild(name: string): (Instance)
WaitForChild​


function Instance:WaitForChild(name: string, timeout: number?): (Instance)
FindFirstDescendant

function Instance:FindFirstDescendant(name: string): (Instance)
FindFirstAncestorOfClass

function Instance:FindFirstAncestorOfClass(name: string): (Instance)
FindFirstAncestor

function Instance:FindFirstAncestor(name: string): (Instance)
Properties
Instance
Instance.Name

string Instance.Name
Instance.Name

Instance Instance.Parent
BasePart
Position

vector BasePart.Position
Size

vector BasePart.Size
CFrame

cframe BasePart.CFrame
Player
DisplayName

string Player.DisplayName
UserId

number Player.UserId

File System
Portal for interaction with C:/v2/data folder within Severe.

Files
checkfile

function checkfile(name: string): (boolean)
Equivalent to isfile

deletefile

function deletefile(name: string): ()
writefile

function writefile(name: string, data: string): ()
readfile

function readfile(name: string): (string)
listfiles

function listfiles(path: string): (table)
 Folder
checkfolder

function checkfolder(name: string): (boolean)
Equivalent to isfolder

deletefolder

function deletefolder(name: string): ()
makefolder

function makefolder(name: string): ()

HTTP
httppost

function httppost(url: string, data: string, content_type: string, accept: string?, cookie: string?, referer: string?, origin: string?): (any)
Performs a POST request with following parameters and returns the response content.

httpget

function httpget(url: string, content_type: string?): (any)
Performs a GET request and returns the response content.

Websockets
websocket_connect

function websocket_connect(url: string): (userdata)
websocket_onmessage

function websocket_onmessage(connection: userdata, callback): ()
websocket_send

function websocket_send(connection: userdata, data: string): ()
websocket_close

function websocket_close(connection: userdata): ()

Base64
base64_encode

function crypt.base64_encode(payload: string): (string)
base64_decode

function crypt.base64_decode(payload: string): (string)

JSON
JSONDecode

function JSONDecode(payload: string): (any)
JSONEncode

function JSONEncode(payload: any): (string)

Keyboard
code for keypress, and keyrelease are defined in this list.

keypress

function keypress(code: number): ()
keyrelease

function keyrelease(code: number): ()
getpressedkeys()

function getpressedkeys(): { string }
getpressedkey()

function getpressedkey(): (string)
Returns the last pressed key.

Mouse
getmouseposition

function getmouseposition(): (x: number, y: number)
mousescroll

function mousescroll(delta: number): ()
mousemoveabs

function mousemoveabs(x: number, y: number): ()
Moves the mouse to absolute x, and y coordinates.

mousemoverel

function mousemoverel(x: number, y: number): ()
Moves the mouse to relative x, and y coordinates.

ismouseiconenabled

function ismouseiconenabled(mouseService): (boolean)
Returns true if the mouse icon is enabled in the given MouseService.

getmouselocation

function getmouselocation(mouseService): (number, number)
getmousebehavior

function getmousebehavior(mouseService): (number)
Returns the current mouse behavior mode: 0 = Default, 1 = LockCenter, 2 = LockCurrentPosition.

getmousedeltasensitivity

function getmousedeltasensitivity(mouseService): (number)
smoothmouse_exponential

function smoothmouse_exponential(origin, point, speed): (number, number)
Applies exponential smoothing between the origin and point vectors at the given speed; recommended for aimbot movement.

smoothmouse_linear

function smoothmouse_linear(origin, point, sensitivity, smoothness): (number, number)
Applies linear smoothing between the origin and point vectors with the specified sensitivity and smoothness; recommended for aimbot movement.

Left Mouse
mouse1click

function mouse1click(): ()
mouse1press

function mouse1press(): ()
mouse1release

function mouse1release(): ()
isleftclicked

function isleftclicked(): (boolean)
isleftpressed

function isleftpressed(): (boolean)
Right Mouse
mouse2click

function mouse2click(): ()
mouse2press

function mouse2press(): ()
mouse2release

function mouse2release(): ()
isrightclicked

function isrightclicked(): (boolean)
isrightpressed

function isrightpressed(): (boolean)

Threading
This portal documents functions that provide multi-threading capabilities.

create

function thread.create(name: string, callback): ()
Creates a separate thread, assigns it with the given name and executes `callback`.

clear

function thread.clear(name: string): ()
suspend

function thread.suspend(name: string): ()
resume

function thread.resume(name: string): ()
terminate

function thread.terminate(name: string): ()

Shared
For communicating in-between threads.

remove

function shared.remove(key: string): ()
has

function shared.has(key: string): (boolean)
set

function shared.set(key: string, value: any): ()
get

function shared.get(key: string): (any)

Drawing
Functions
Drawing.new

function Drawing.new(class: string): (object)
Create a new object of specified class, see sub-pages for valid classes.

Drawing.clear

function Drawing.clear(): ()
Destroys all active objects.

Default
Properties
Object.Visible

boolean Object.Visible
Determines whether the object is rendered.

Object.ZIndex

number Object.ZIndex [-2147483647, 2147483647]
Determines the order in which the object is rendered relative to other objects.

Object.Color

array Object.Color 
Determines the color of the object.

Object.Opacity

number Object.Opacity [0-1]
A value between 0 and 1 that indicates the opacity of a object, where 0 is fully transparent and 1 is fully opaque.

Methods
Object:Remove

function Object:Remove()
Effectively destroys the object.

Line
Inherits from Default

Properties
Line.Thickness

number Line.Thickness
Determines the thickness of a Line in pixels.

Line.From

vector Line.From
Determines the starting position of a Line.

Line.To

vector Line.To
Determines the end position of a Line.

Text
Inherits from Default

Properties
Text.Outline

boolean Text.Outline
Determines whether the displayed text is outlined.

Text.Center

boolean Text.Center
Determines whether the displayed text is centered.

Text.Font

number Text.Font [0-31]
Determines the font used for the text object.

Text.Size

number Text.Size
Determines the font size of the text object.

Text.Position

vector Text.Position
Determines the position of the text object.

Text.TextBounds

vector Text.TextBounds [readonly]
Describes the vector space occupied by the text object.

Text.OutlineColor

array Text.OutlineColor
Determines whether the displayed text is outlined.

Text.Text

string Text.Text
Determines the text to be displayed.

Image
Inherits from Default

Properties
Image.Url

string Image.Url
Determines the URL of the image.

Image.Data

string Image.Data
Used for loading the image from the file system.

Image.Gif

boolean Image.Gif
Determines whether the image is a GIF.

Image.Delay

number Image.Delay
Determines the delay between GIF frames.

Image.Position

vector Image.Position
Determines the position of the image.

Image.Size

vector Image.Size
Determines the size of the image.

Image.Rounding

number Image.Rounding
Determines the corner rounding of the image.

Image.ImageSize

vector Image.ImageSize [readonly]
Describes the original size of the image.

Circle
Inherits from Default

Properties
Circle.Thickness

number Circle.Thickness
Determines the thickness of the circle's outline.

Circle.NumSides

number Circle.NumSides
Determines the number of sides used to approximate the circle.

Circle.Radius

number Circle.Radius
Determines the radius of the circle.

Circle.Filled

boolean Circle.Filled
Determines whether the circle is filled.

Circle.Position

vector Circle.Position
Determines the position of the circle's center.

Square
Inherits from Default

Properties
Square.Thickness

number Square.Thickness
Determines the thickness of the square's outline.

Square.Size

vector Square.Size
Determines the size of the square.

Square.Position

vector Square.Position
Determines the position of the square.

Square.Filled

boolean Square.Filled
Determines whether the square is filled.

Square.Rounding

number Square.Rounding
Describes the roundness of a square's corners.

Triangle
Inherits from Default

Properties
Triangle.Thickness

number Triangle.Thickness
Determines the thickness of the triangle's outline,  ignored if Triangle.Filled is true.

Triangle.PointA

vector Triangle.PointA
Determines the position of triangle's first point.

Triangle.PointB

vector Triangle.PointB
Determines the position of triangle's second point.

Triangle.PointC

vector Triangle.PointC
Determines the position of triangle's third point.

Triangle.Filled

boolean Triangle.Filled
Determines whether the triangle is filled.

Quad
Inherits from Default

Properties
Quad.PointA

vector Quad.PointA
The position of quad's first point.

Quad.PointB

vector Quad.PointB
The position of quad's second point.

Quad.PointC

vector Quad.PointC
The position of quad's third point.

Quad.PointD

vector Quad.PointD
The position of quad's fourth point.

Quad.Thickness

number Quad.Thickness
Determines the thickness of the quad's outline, ignored if Quad.Filled is true.

Quad.Filled

boolean Quad.Filled
Determines whether the quad is filled.

Internal
Types
qword

dword

string

double

float

bool

Functions
pointer_to_table_data

function pointer_to_table_data(pointer: number): (table)
For use within the Roblox Luau annotation.

pointer_to_user_data

function pointer_to_user_data(pointer: number): (userdata)
getmemoryvalue

function getmemoryvalue(object: userdata, offset: number, type: string): (any)
setmemoryvalue

function setmemoryvalue(object: userdata, offset: number, type: string, value: any): ()
Reflection
Low strength causes setmemoryvalue / readmemoryvalue to be faster in exchange for their reliability. This is useful incase you're working with a lot of objects. High strength can cause thread lag.

SET_MEMORY_WRITE_STRENGTH

function SET_MEMORY_WRITE_STRENGTH(strength: number): ()
SET_MEMORY_READ_STRENGTH

function SET_MEMORY_READ_STRENGTH(strength: number): ()
GET_MEMORY_WRITE_STRENGTH

function GET_MEMORY_WRITE_STRENGTH(): (number)
GET_MEMORY_READ_STRENGTH

function GET_MEMORY_READ_STRENGTH(): (number)

Models
override_local_data

function override_local_data(data: table): (none)
Initializes and stores local player–related data from the Lua environment into the internal Data structure.

Player Data Schema:

LocalPlayer: Reference to the player object.

Displayname: Visible name of the player.

Username: Player's account username.

Userid: Unique player ID.

Character: Player's character model reference.

Team: (Optional) Player's team object.

RootPart: Main character part (e.g., HumanoidRootPart).

LeftFoot, Head, LowerTorso: Specified character parts.

Tool: (Optional) Equipped tool or weapon.

Humanoid: Controls the character.

Health, MaxHealth: (Optional) Current and max health values.

RigType: Rig type indicator (0 for R6, 1 for R15).

Usage Example:


local data = {
  LocalPlayer = Player,
  Displayname = Player.DisplayName,
  Username = Player.Name,
  Userid = Player.UserId,
  Character = Player.Character,
  -- ... other fields ...
}
override_local_data(data)
add_model_data

function add_model_data(data: table, key: string): (none)
Registers a new character model entry under the specified key, storing data used for targeting, visualization, and status tracking.

Player Data Schema:

Displayname: Player's display name (String)

Userid: Unique player ID (Number)

Character: Reference to the character model (Instance)

PrimaryPart: Main body part, e.g., HumanoidRootPart (Instance)

Body Parts: Head, LeftLeg, RightLeg, LeftArm, RightArm, Torso

BodyHeightScale: Height scale multiplier (Number)

RigType: Rig type, R6 (0) or R15 (1) (Number)

Whitelisted: Exemption from hostile logic (Boolean)

Archenemies: Marked as hostile (Boolean)

Aimbot_Part: Preferred aimbot target (Instance)

Aimbot_TP_Part: Aimbot TP target part (Instance)

Triggerbot_Part: Triggerbot activation part (Instance)

Health: Current health (Number)

MaxHealth: Maximum health (Number)

Body Parts Data: Specific data for chams/skeleton (Table)

Full Body Data: All related body parts (Table)

Usage Example:


local data = {
  Username = "Player1",
  Displayname = "CoolPlayer",
  Userid = 123456,
  Character = workspace.Player1.Character,
  PrimaryPart = workspace.Player1.Character.HumanoidRootPart,
  -- ... other fields ...
}
add_model_data(data, "key_1")
edit_model_data

function edit_model_data(data: table, key: string): (none)
Applies partial updates to an existing model entry identified by key, modifying only the provided fields.

Player Data Schema:

RigType: Indicates the updated number for the rig type.

Whitelisted: Represents a boolean flag for exclusion status.

Archenemies: A boolean flag indicating hostility status.

Aimbot_Part: Specifies a new target part for the aimbot.

Aimbot_TP_Part: Defines a new teleport part for the aimbot.

Triggerbot_Part: Designates a new triggerbot part.

Health: Updates the current health value.

MaxHealth: Provides the updated maximum health.

BodyHeightScale: Updates the height scale.

Usage Example:


local edit = {
  Health = 50,
  MaxHealth = 100,
  Aimbot_Part = targetHead
}
edit_model_data(edit, "key_1")
