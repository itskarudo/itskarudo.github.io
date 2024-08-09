+++
title = "C++ Internals for Hackers: Part 1"
+++
# Introduction

When starting to learn reverse engineering, you usually start with C binaries, throwing it into IDA or Ghidra, and scrolling up and down while renaming all your little variables, maybe you're a CTF player and most binary exploitation challenges you face are written in C, how convenient. But at some point you need to leave your comfort zone, not all programs are written in C, a lot of malware nowadays for example is written in a higher level language such as Go, Zig, or Rust. The main reason for this is that these languages provide a richer standard library than what the C standard library has to offer. This transition can be very daunting because as they say, C is a high level assembly language, with enough time you will be able to read a C program and know exactly how the resulting assembly is going to be. But other languages provide advanced features such as Go's goroutines, Rust's `?` syntax with the `Result` type, and other features that do not directly translate in a decompiler.

I believe C++ is a nice language to start the transition from C to other languages. It is not as verbose as other languages, has similar type system to C, and overall results in a relatively decent decompiler output. It also has support for other not trivial features such as function overloading, inheritance, and many syntactic sugar sparkled here and there.

In this series I will try giving you an overview on how some C++ features work internally, by comparing what C++ developers take for granted and its corresponding assembly output, I will be assuming familiarity with C reverse engineering and Object Oriented Programming concepts, some C++ knowledge is preferable but I'll try my best  to explain things as I go on :)

# Function Overloading and Name Mangling

C++ has this neat feature where you can define multiple functions with the same name as long as they have different argument types.

```cpp
int add(int a, int b) {
	return a + b;
}

double add(double a, double b) {
	return a + b;
}


int main(void) {
	int int_result = add(1, 2);
	double double_result = add(1.5, 2.5);
}
```

This is not legal in C since it uses the function name only to determine which function to call, but in C++ things are a bit different. C++ uses a technique known as [Name Mangling](https://en.wikipedia.org/wiki/Name_mangling), instead of using the function's name by itself, it uses a combination of the function's name and argument types and generates a new name for the function based on that.

If you compile the previous code and open it in IDA, you will see the following output:

```nasm
mov     esi, 2          ; int
mov     edi, 1          ; int
call    _Z3addii        ; add(int,int)
mov     [rbp+var_C], eax
movsd   xmm0, cs:qword_2008
mov     rax, cs:qword_2010
movapd  xmm1, xmm0      ; double
movq    xmm0, rax       ; double
call    _Z3adddd        ; add(double,double)
```

You see the `_Z3addii` and `_Z3adddd`? those are our mangled names. You can see what they translate to next to each corresponding `call` instruction as a comment, you can also use [demangler.com](https://demangler.com/) to see that.

This simple feature is also what implements [namespaces](https://en.cppreference.com/w/cpp/language/namespace), [nested types](https://en.cppreference.com/w/cpp/language/nested_types) and [static members](https://en.cppreference.com/w/cpp/language/static).

## extern "C"
Take the following example of using C and C++ together:

```cpp
// file1.c
void foo(int x) {
	printf("x is %d\n", x);
}

// file2.cpp
void foo(int x);

int main(void) {
	foo(5);
}
```

If you compile these files into object files, the C file with `gcc` and the C++ file with `g++`, then try and link them, you will get the following error:

```
undefined reference to `foo(int)'
```

What is causing that? Well, as we've established, C does not mangle function names, so the exported symbol in the C object file will carry the name `foo`, but `foo` when declared in the C++ file will have the mangled name `_Z3fooi`, this is the name the linker looks for in the C object which can not find so it reports an error.

To fix this you need to tell the C++ compiler to disable name mangling for this function, this is done by the `extern "C"` syntax:

```cpp
extern "C" void foo(int x);
```

[You might have seen this syntax in header files of libraries written in C before](https://github.com/protocolbuffers/protobuf/blob/main/php/ext/google/protobuf/php-upb.h#L288), this is essentially providing compatibility for C++ code to use these header files without having to redeclare every function you need to use.

# Classes, Structs and Methods

## class vs struct

One of the main differences often told about C and C++ is classes, well sorry to break it to you but in C++, classes and structs are identical [^1]. When stumbling upon complex data structures while reverse engineering C++ you can really just think of them as structs. The real difference is in the extra features C++ adds to the syntax.

## Methods

Let's take a look at the following C code:

```c
struct IntArray {
	unsigned int size;
	unsigned int capacity;
	int* data;
};

int int_array_get(struct IntArray* arr, unsigned int idx) {
	assert(idx < arr->size);
	return arr->data[idx];
}

int main(void) {
	struct IntArray arr = reate_new_int_array();
	
	int x = int_array_get(arr, 0);
}
```

If you're familiar with OOP patterns, you might notice this is just the definition of a class and a method for said class, let's write it in a more C++-y way:

```cpp
struct IntArray {
	unsigned int size;
	unsigned int capacity;
	int* data;

	int get(unsigned int idx) {
		assert(idx < this->size);
		return this->data[idx];
	}
};

int main(void) {
	struct IntArray arr = create_new_int_array();
	
	int x = arr.get(0);
}
```

As you can see, by making the `get` function a method, we remove the need of passing the `arr` variable, C++ gives us a handy variable called `this` which is a pointer to the current object. If you're familiar with other OOP langauges such as Java this would feel right at home.

How does this work? exactly as the C code.

```nasm
call   _Z20create_new_int_arrayv ; create_new_int_array()
mov    QWORD PTR [rbp-0x20], rax    
mov    QWORD PTR [rbp-0x18], rdx                                   
lea    rax, [rbp-0x20]
mov    esi, 0x0
mov    rdi, rax
call   <_ZN8IntArray3getEj       ; IntArray::get(unsigned int)
```

As you can see, the first argument passed to `IntArray::get` is a pointer to the the `arr` variable (check the `rdi` register), and every other argument is just shifted in position.

# Operator Overloading

Let's take another look at out previous example. Even though the `arr.get(0)` syntax works fine, it still feels a bit clunky, since our variable is really an array we would really like to have an array-like syntax for random access such as `arr[0]`. This is where operator overloading comes into play.

Operator overloading is a way to define or modify how your object behaves with different operators. You might have seen the classic C++ hello world:

```cpp
int main(void) {
	std::cout << "hello world!" << std::endl;
}
```

Those little `<<` things are operators defined on the `std::iostream` type, which `std::cout` is an instance of.

Let's see how that looks in our class:

```cpp
struct IntArray {
	unsigned int size;
	unsigned int capacity;
	int* data;

	int operator[](unsigned int idx) {
		assert(idx < this->size);
		return this->data[idx];
	}
};

int main(void) {
	struct IntArray arr = create_new_int_array();
	
	int x = arr[0];
}
```

Defining operators is as simple as defining a method called `operatorX`, these names are mangled and used just like normal functions. You can think of it as something like:

```cpp
IntArray::operator[](this, 0);
```

This feature, along side being the source of [many cursed C++ code](https://www.reddit.com/r/cpp/comments/139c2v1/whats_the_most_hilarious_use_of_operator/), is what strikes a lot of fear for people decompiling a C++ binary for the first time, because something as simple looking as:

```cpp
std::vector<int> arr = {1,2,3};
int v = arr[0];
```

After resolving all the type aliasing and overloads, will turn into something like:
```cpp
int v = std::vector<int,std::allocator<int>>::operator[](arr, 0);
```

Honestly, this just takes some getting used to, the types on non-stripped binaries are easy to understand, just takes a bit of practice.

## Conclusion
So this concludes the first part of this series, in the next part we will be taking a look at how inheritance and virtual function overrides work, see ya!

---

[^1]: Not really, they differ in the default visibility of members. https://stackoverflow.com/a/54596
