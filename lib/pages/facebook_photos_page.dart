import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nudges_flutter/util/user_data.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class FacebookPhotosPage extends StatefulWidget {
  final String albumId;
  const FacebookPhotosPage({Key key, @required this.albumId}) : super(key: key);
  @override
  _FacebookPhotosPageState createState() => new _FacebookPhotosPageState();
}

class _FacebookPhotosPageState extends State<FacebookPhotosPage> {
  final double aspectRatio = 0.8;
  final double gap = 10.0;
  final int imagesPerRow = 4;

  int showLimit = 24;
  int offset = 0;
  List<dynamic> images;

  @override
  void initState() {
    super.initState();

    loadAlbums();
  }

  loadAlbums() async {
    var graphResponse = await http.get(
        'https://graph.facebook.com/v3.2/${widget.albumId}/photos?fields=images&type=large&limit=$showLimit&offset=$offset&access_token=${UserData.accessToken}');
    setState(() {
      if(images == null)
        images = json.decode(graphResponse.body)["data"];
      else
        images.addAll(json.decode(graphResponse.body)["data"]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Import from Facebook')),
        body: images==null?new LinearProgressIndicator():Column(children:[
          Expanded(child:GridView.count(
              childAspectRatio: aspectRatio,
              padding: EdgeInsets.all(gap),
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              // Create a grid with 2 columns. If you change the scrollDirection to
              // horizontal, this would produce 2 rows.
              crossAxisCount: imagesPerRow,
              // Generate 100 Widgets that display their index in the List
              children: List.generate(images.length, (index) {
                return buildImage(context,index);
              }))),
          images.length>=showLimit+offset?FlatButton(child:Text("Load More"),onPressed: (){
            loadMore();
          }):Container()
        ]));
  }

  loadMore(){
    this.offset+=this.showLimit;
    loadAlbums();
  }

  Widget buildImage(BuildContext context, int index) {
    return GestureDetector(
      child: Image.network(
        images[index]["images"][0]["source"].toString(),
        fit: BoxFit.fill,
      ),
      onTap: () {selectImage(context,index);},
    );
  }

  selectImage(BuildContext context, int index) {
    //print("Selected");
    Navigator.pop(context, images[index]["images"][0]["source"].toString());
    //final image = Navigator.push(context,MaterialPageRoute(builder: (context) => FacebookPhotosPage()));
  }
}
