# hello_me

Question 1:
The class that is used to implement the controller pattern in this library is the snappingSheetController Widget.
It controls the positions of the snappingsheet.
It contains a property named snapPositions, which as the name indicates, holds the sheet's snap positions.
It contains a method named snapToPosition, which as the name indicates, can change the snap position.

Question 2:
SnappingSheet class contains a property named snapPositions, which is a list which saves the different snapping positions for the SheetBelow.

Question 3:
InkWell and GestureDetector are very similar, as both almost have the same features, but:
GestureDetector is more broad and provides more complex options.
While the InkWell is just a child of the material widget.
One advantage of the GestureDetector over the InkWell is that it is able to provide more gestures, and that it's not related to a material father.
One advantage of the InkWell over the GestureDetector is that the InkWell is a rectangle area of Material that responds to ink splashes, so it has effects such as ripple effect tap and other ink related features that aren't available in GestureDetector.