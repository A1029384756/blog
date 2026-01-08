---
title: Why IMGUI
date: '2026-01-07T00:00:00.000Z'
draft: false
tags:
  - UI
  - Programming
---

> Authors note: The sample code in this article will sometimes be modified
  to be less "correct" in favor of brevity to better convey ideas with
  less syntactic noise.

## Introduction
In my conversations I've had about UI, there has been much debate about
immediate and retained mode, their differences, and what the "better"
paradigm is for different applications. During these discussions, I've often
seen the term "immediate mode" used to define a very specific kind of UI
paradigm that doesn't reflect the implementations seen in the wild. There
are also many misconceptions about what immediate and retained mode even mean
and as a result, some false conclusions drawn about the viability of using
different paradigms in different scenarios. Before we can discuss each paradigm
in depth though, we must first learn what each paradigm is and what makes them
tick.

## Retained Mode
To start, retained mode is the more widely known and recognized of the two
paradigms with a very rich history. Many widely used UI toolkits have been
made that make use of this style. To name a few:
- QT
- GTK
- WinUI
- The DOM
- Many more...

These toolkits alone power a large portion of graphical software and
for good reason; the tooling is very mature, reference material is abundant,
and the "object model" is logically very easy to grasp for many people,
where a widget maps to an "object" with its own set of properties and
actions.

Generally, retained mode APIs follow this style:
```cs
class MainWindow : Window
{
  public MainWindow()
  {
    this.InitializeComponent();
  }

  private async void myButton_Click(object sender, RoutedEventArgs e)
  {
    ContentDialog dialog = new ContentDialog();
    dialog.XamlRoot = this.Content.XamlRoot;
    dialog.Title = "Welcome";
    dialog.Content = txtName.Text;
    dialog.PrimaryButtonText = "OK";

    await dialog.ShowAsync();
  }
}
```
> This code is lightly modified from this [WinUI example](https://github.com/MicrosoftDocs/windows-topic-specific-samples/tree/winui-3/tutorials/winui-notes/WinUINotes/WinUINotes).

As you can see, the main idea is that widgets are "objects" in the classical
sense with methods attached to them to perform actions. These objects also have
properties on them that can be set to update the UI at any time. The astute
reader might also notice that `myButton_Click` doesn't seem to have anything
that calls it. This is because in this case (WinUI), there is actually a
*separate* `xaml` file that holds the following xml:
```xml
<Button 
  x:Name="myButton" 
  Content="Click Me"
  Click="myButton_Click" 
  HorizontalAlignment="Center"
  Style="{StaticResource AccentButtonStyle}"
/>
```
This file holds information about the button, where it goes on the screen, and
how it should interact with the code behind it. In larger teams
this offers a nice benefit: the ability to (easily) split layout, styling,
and logic at the API level. This allows much of the UI to be defined in
a discrete "builder" application where users can drag and drop widgets into
their desired locations and configure their visuals without writing a single
line of code. This can be extremely powerful when you have a team that has
separate designers and programmers as it allows them to work relatively
independently of one another.

Another example of this is using the web without any frameworks. Designers can
either use their builder applications or directly use HTML and CSS to define a
UI while the functionality/logic of the application is then separately defined in
Javascript.

Although this separation is a pro in some regards, this isn't without its 
drawbacks. For teams that are smaller or more programmer-centric, this can 
often result in context-switching between UI design and programming, slowing them 
down overall. In addition to this, the object model can often feel much less
direct and results in much more fiddly widget state management as the
programmer is now left in charge of managing the various widgets, their internal
state, and their lifetimes.

To combat this somewhat, toolkits like QT have begun shifting their 
recommended APIs towards a declarative approach. This can be seen with QTs QML 
that looks like:
```qml
component OperatorButton: CalculatorButton {
  dimmable: true
  implicitWidth: 48
  textColor: controller.qtGreenColor
  
  onClicked: {
    controller.state.operatorPressed(text);
    controller.updateDimmed();
  }
}
```
> From the [QT Calculator Demo](https://code.qt.io/cgit/qt/qtdoc.git/tree/examples/demos/calqlatr?h=6.10)

Here, the widget logic and component code are placed directly next to one
another, improving the locality of behavior. However, the model of "object"
with properties is still maintained. There also seems to be very little actual
*application* logic contained in the click handler, why is that? 
Well, the thing is, even with this more contained approach where the 
description of widgets and their internal logic are placed next to one another, 
the application or business logic is placed elsewhere. This is a result of a
pattern that has commonly emerged in retained-mode UI frameworks called 
"Model-View-Controller" (MVC).

Model-view-controller at its core centers around creating an orderly way
for graphical applications to interact with and manage their state. Each
portion of the pattern has its own role:
- Model: the application state
- View: the interface the user sees/interacts with
- Controller: code that updates the model upon input from the user

// [TODO] Put image here

As you can see, MVC follows a circular pattern that maps well to the "event loop"
that powers basically every application. One can:
- Read from the model and render the view
- Accept user input from the view
- Perform associated controller actions to update the model
- Repeat ad infinitum

This also adds a number of easy optimization paths since controller actions are 
discrete events. Using this information, certain steps such as rendering the view
can be skipped when no controller actions have been taken, saving power in cases
where the application is idle (important for battery-powered devices).

In recent years, a more constrained version of MVC called the Elm Architecture has 
grown in popularity. At its core, it uses the same principles but applies that
to *every* widget, making a widget into something like the following:
```elm
module Main exposing (..)

import Browser
import Html exposing (Html, button, div, text)
import Html.Events exposing (onClick)

main =
  Browser.sandbox { init = init, update = update, view = view }

type alias Model = Int

init : Model
init =
  0

type Msg
  = Increment
  | Decrement

update : Msg -> Model -> Model
update msg model =
  case msg of
    Increment ->
      model + 1
    Decrement ->
      model - 1

view : Model -> Html Msg
view model =
  div []
    [ button [ onClick Decrement ] [ text "-" ]
    , div [] [ text (String.fromInt model) ]
    , button [ onClick Increment ] [ text "+" ]
    ]
```
> The [Button Example](https://elm-lang.org/examples/buttons) from the Elm Docs

The syntax might look a little alien to some but there are some important things
to note in this case:
- The view and update logic can reside in the same place
- One doesn't *have* to use a traditionally "object oriented" language
- Events are now typed messages that get consumed by the update logic

This leads to a more structured model overall and is reasonably easy for a
programmer to write, as the view logic can be laid out in a simple, declarative
manner with the side effects being tied to messages with easily identifiable
update logic.

There are some "magic" details though that I have been largely overlooking
that do make this style of API difficult to implement depending on the language.
So far, each of the examples I have shown use some sort of garbage collection and
heavy runtime:
- WinUI: C#
- QML: Javascript
- Elm: Compiled to Javascript

QT and WinUI also have official C++ APIs but they make extensive use of destructors
which are not part of every language. Those without them then need to manually
delete each widget as it goes off-screen. Additionally, these APIs end up splitting
the code up more again, reducing the locality of behavior to an unpleasant degree.
This splitting ends up resulting in a callback-heavy API which makes state management
trickier and is overall harder to work with. As a result, alternative solutions need
to be explored to reduce the complexity of implementation and usage for those who do
not want to use certain language features.

## IMGUI
I would be remiss to even mention IMGUI without first mentioning the video
by Casey Muratori which contains one of the earliest formal descriptions of using
this this technique and can be found [here](https://caseymuratori.com/blog_0001).

The promise of IMGUI is very simple at its core:
```odin
if button() {
  // do stuff
}
```

The idea is that widgets are simply functions that return values. Although this
technique was initially relegated to debug UIs, it found an unlikely champion
in the form of the web.

Many "modern" web frameworks build an immediate mode API over the retained mode
API of the DOM (this is important for later). React is probably the most well-known
example of this with the following example code:
```jsx
function Video({ video }) {
  return (
    <div>
      <Thumbnail video={video} />
      <a href={video.url}>
        <h3>{video.title}</h3>
        <p>{video.description}</p>
      </a>
      <LikeButton video={video} />
    </div>
  );
}
```
As you can see, a component is quite literally just a function that returns UI to
render. This might seem odd at first but it does offer a valuable benefit: the widget
hierarchy is a *property* of the function call stack, meaning that widget lifetimes 
now don't have to be managed manually and instead are implicit to the code that you
are running. To give an example:
```odin
for elem in elems {
  elem_widget(elem)
}
```
The above code renders a list of elements. Simple enough right? Well what happens if 
an element is removed from the list? Interestingly enough, there is no need to "delete"
the element widget from the list, it simply doesn't exist the next time the UI code runs.

Another example of this can be seen here:
```odin
if render_options_menu {
  options_menu()
}
```
`options_menu` is only ever called if `render_options_menu` is `true`, meaning that
it only ever renders itself (and any children) when the condition is met. This makes
managing visibility dead simple as something can quite literally only be visible when
the respective code actually runs.

thinking in imguis

conclusion
