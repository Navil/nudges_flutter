import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:nudges_flutter/pages/Config.dart';
import 'package:nudges_flutter/pages/facebook_albums_page.dart';
import 'package:nudges_flutter/pages/options_page.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nudges_flutter/util/user_data.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageStage createState() => new _EditProfilePageStage();
}

class _EditProfilePageStage extends State<EditProfilePage> {
  List images = [];

  bool _loading = false;
  final double aspectRatio = 0.7;
  final double gap = 10.0;
  final int imagesPerRow = 3;

  @override
  initState() {
    super.initState();
    // Add listeners to this class
    Firestore.instance
        .collection("users")
        .document(UserData.uid)
        .snapshots()
        .forEach((DocumentSnapshot snapshot) {
          if(mounted){
            setState(() {
              this.images = new List.from(snapshot.data["images"]);
            });
          }

    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: _loading?AppBar(leading: Container(),title: Text("Edit Images")):AppBar(title: Text("Edit Images")),
        body:new Stack(children:[ new Column(
            children: [
          new Expanded(
              child: GridView.count(
            childAspectRatio: aspectRatio,
            padding: EdgeInsets.all(gap),
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            // Create a grid with 2 columns. If you change the scrollDirection to
            // horizontal, this would produce 2 rows.
            crossAxisCount: imagesPerRow,
            // Generate 100 Widgets that display their index in the List
            children: List.generate(9, (index) {
              bool isImage = images.length > index;
              return Stack(
                children: [
                  isImage
                      ? generateImage(context, index)
                      : generatePlaceholder(context, index),
                  Positioned(
                      child: Text((index + 1).toString(),
                          style:
                              TextStyle(fontSize: 20.0, color: Colors.white)),
                      left: 7.0,
                      top: 7.0),
                  isImage
                      ? Positioned(
                          bottom: -10.0,
                          right: -10.0,
                          child: IconButton(
                              iconSize: 30.0,
                              icon: Icon(Icons.cancel),
                              onPressed: () {onDeletePressed(index);},
                              color: Colors.red.withOpacity(0.8)))
                      : Positioned(
                          bottom: -10.0,
                          right: -10.0,
                          child: IconButton(
                              iconSize: 30.0,
                              icon: Icon(Icons.add_circle_outline),
                              onPressed: () {
                                addImage(context);
                              },
                              color: Theme.of(context).primaryColor))
                ],
                fit: StackFit.expand,
              );
            }),
          )
          ),
          //new Expanded(child:Text("Ho"))
          //Text("Personal Information",
              //style: Theme.of(context).textTheme.headline)
        ]), _loading?Stack(children: [new Opacity(
          opacity: 0.5,
          child: ModalBarrier(dismissible: false, color: Theme.of(context).primaryColorLight),
        ),
          new Center(
            child: new Column(mainAxisAlignment:MainAxisAlignment.center,children:[
              new CircularProgressIndicator(valueColor: new AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor)),
              SizedBox(height:5.0),
              Text("Loading...",style: TextStyle(fontSize: 20.0),)])
          )]):Container()
        ]
        )
    );
  }

  addImage(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return new AlertDialog(
          titlePadding: EdgeInsets.all(0.0),
          title: Container(padding:EdgeInsets.all(20.0),color:Theme.of(context).primaryColor,child:Row(children:[ Text('Select Source',style: TextStyle(color: Theme.of(context).primaryColorLight),)])),
          content: new Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              //_buildAboutText(),
              new ListTile(leading: Icon(Icons.image, color: Colors.black), title: Text("Select from Images"), onTap: () {
                Navigator.pop(context);
                importImageFromGallery(ImageSource.gallery);
              }),
              new ListTile(leading: Icon(Icons.camera_alt, color: Colors.black), title: Text("Take a Photo"), onTap: () {
                Navigator.pop(context);
                importImageFromGallery(ImageSource.camera);
              }),
              UserData.accessToken==null?Container():new ListTile(leading: Icon(MdiIcons.facebook, color: Colors.black), title: Text("Import from Facebook"),onTap: () {
                Navigator.pop(context);
                importImageFromFacebook(context);
              }),
              //_buildLogoAttribution(),
            ],
          ),
        );
      },
    );
  }

  importImageFromGallery(ImageSource source) async{
    File file = await ImagePicker.pickImage(source: source);
    if(file == null)
      return;

    prepareImageForUpload(file.path);
  }
  uploadImages() async{
    Firestore.instance.collection("users").document(UserData.uid).updateData({"images":this.images});
    this._loading = false;
  }
  Widget generatePlaceholder(BuildContext context, int index) {
    return new Container(
        decoration: new BoxDecoration(
            color: Theme.of(context).primaryColorLight.withOpacity(0.8)));
  }

  Widget generateImage(BuildContext context, int index) {
    Widget image = DragTarget<int>(
      builder: (BuildContext context, List candidateData, List rejectedData) {
        //print("DragTerget");
        return Image.network(images[index]["downloadURL"], fit: BoxFit.fill);
      },
      onAccept: (int toMoveIndex) {
        print("You want to move image: " + toMoveIndex.toString());
        setState(() {
          var movedImage = images[toMoveIndex];
          if (toMoveIndex > index) {
            //Move everything between movedIndex and Index to the left
            //Put movedImage to index
            for (; toMoveIndex > index; toMoveIndex--) {
              images[toMoveIndex] = images[toMoveIndex - 1];
            }
            images[index] = movedImage;
            uploadImages();
          } else if (toMoveIndex < index) {
            for (; toMoveIndex < index; toMoveIndex++) {
              images[toMoveIndex] = images[toMoveIndex + 1];
            }
            images[index] = movedImage;
            uploadImages();
          }
          //images.insert(index, element)
        });
        //return true;
      },
    );
    return Draggable(
        child: Container(
          child: image,
        ),
        feedback: Container(
            child: image,
            width: MediaQuery.of(context).size.width / imagesPerRow - gap,
            height: MediaQuery.of(context).size.width /
                    (imagesPerRow * aspectRatio) -
                2 * gap),
        data: index);
  }

  onDeletePressed(int index) async{
    setState(() {
      this._loading = true;
    });
    await FirebaseStorage.instance.ref().child(UserData.uid).child("profile_images").child(images[index]["filename"]).delete();
    images.removeAt(index);
    uploadImages();
  }

  void importImageFromFacebook(BuildContext context) async{
    final image = await Navigator.push(context,MaterialPageRoute(builder: (context) => FacebookAlbumsPage()),
    );
    if(image == null)
      return;

    print("Got image: "+image);

    Uint8List response = await http.readBytes(image);
    final String filename = (await getTemporaryDirectory()).path+"/temp.jpg";
    File file = await new File(filename).writeAsBytes(response);
    prepareImageForUpload(file.path);

  }

  void prepareImageForUpload(String path) async{
    File croppedFile = await ImageCropper.cropImage(
      toolbarColor: Theme.of(context).primaryColor,
      sourcePath: path,
      ratioX: 0.7,
      ratioY: 1.0,
      maxWidth: Config.imageWidth,
      maxHeight: Config.imageHeight,
    );
    if(croppedFile == null)
      return;
    setState(() {
      this._loading = true;
    });
    String filename = Config.guid();
    StorageTaskSnapshot task = await FirebaseStorage.instance.ref().child(UserData.uid).child("profile_images").child(filename).putFile(croppedFile).onComplete;
    String url = await task.ref.getDownloadURL();

    setState((){
      images.add({"downloadURL": url,"filename": filename});
      uploadImages();
    });
  }

}
