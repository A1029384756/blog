---
title: Why IMGUI
date: '2026-01-07T00:00:00.000Z'
draft: false
tags:
  - UI
  - Programming
---

## Introduction
In my conversations I've had about UI, there has been much debate about
immediate and retained mode, their differences, and what is the "better"
paradigm for different applications. During these discussions, I've often
seen the term "immediate mode" used to define a very specific kind of UI
paradigm that doesn't reflect the implementations seen in the wild. There
are many misconceptions about what immediate and retained mode even mean
and as a result, some false conclusions drawn about the viability of using
different paradigms in different scenarios.

## Retained Mode
To start, retained mode is the better known and recognized of the two
paradigms with a very rich history. Many widely used UI toolkits have been
made that make use of this style. To name a few:
- QT
- The DOM
- GTK
- WinUI
- Many more...

These toolkits alone make up a large portion of graphical software and
for good reason, the tooling is very mature, reference material is abundant,
and the "object model" is logically very easy to grasp for many people,
where a widget maps to an "object" with its own set of properties and
actions.

Generally, retained mode APIs follow this style:
```cs
public sealed partial class MainWindow : Window
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
In here, the information about the button, where it goes on the screen, and
what methods are associated with various actions are encoded. In larger teams
this is actually quite a nice benefit: how simple it is to split layout/styling
and logic at the API level. This allows much of the UI to be defined in
a discrete "builder" application where users can drag and drop widgets into
their desired locations and configure their visuals without writing a single
line of code. This can be extremely powerful when you have a team that has
separate designers and programmers as it allows them to work relatively
independently of one another.

Another example of this is using the web without any frameworks. Designers can
either use their builder applications or directly use HTML and CSS to define a
UI and the functionality/logic of the application is then separately defined in
Javascript.

Although this separation is a pro in some regards, this isn't without its 
drawbacks. For teams that are smaller or more programmer-centric, this can 
often result in context-switching between UI design and programming, slowing them 
down overall. In addition to this, the object model can often feel much less
direct and results in much more fiddly state management overall as the
programmer is now left in charge of managing the various widgets and
their lifetimes.

To combat this somewhat, toolkits like QT have begun shifting their 
recommended APIs towards a very declaratively styled approach. This can
be seen with QTs QML code that looks like:
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

Here, the actions and component are once again placed directly next to one
another, improving the locality of behavior. However, the model of "object"
with properties is still maintained.

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
