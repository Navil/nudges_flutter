import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nudges_flutter/pages/facebook_photos_page.dart';
import 'package:nudges_flutter/util/user_data.dart';
import 'package:http/http.dart' as http;

class FacebookAlbumsPage extends StatefulWidget {
  @override
  _FacebookAlbumsPageState createState() => new _FacebookAlbumsPageState();
}

class _FacebookAlbumsPageState extends State<FacebookAlbumsPage> {
  final double aspectRatio = 0.8;
  final double gap = 10.0;
  final int imagesPerRow = 2;

  int showLimit = 10;
  int offset = 0;
  List<dynamic> albums;

  @override
  void initState() {
    super.initState();

    loadAlbums();
  }

  loadAlbums() async {
    var graphResponse = await http.get(
        'https://graph.facebook.com/v3.2/me/albums?fields=cover_photo{picture},name,count&limit=$showLimit&offset=$offset&access_token=${UserData.accessToken}');
    //print(graphResponse.body.toString());
    setState(() {
      if(albums == null)
        albums = json.decode(graphResponse.body.toString())["data"];
      else
        albums.addAll(json.decode(graphResponse.body.toString())["data"]);
      //print(albums.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Import from Facebook')),
        body: albums == null
            ? new LinearProgressIndicator()
            : Column(children:[Expanded(child:new ListView.builder(
                itemCount: albums.length,
                padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 5.0),
                itemBuilder: (BuildContext context, int index) {
                  return buildAlbum(context,index);
                })),albums.length>=showLimit+offset?FlatButton(child:Text("Load More"),onPressed: (){loadMore();}):Container()])
    );
  }
  loadMore(){
    this.offset+=this.showLimit;
    loadAlbums();
  }
  Widget buildAlbum(BuildContext context,int index) {
    return Column(children: [
      ListTile(
        onTap: () {
         openAlbum(context,index);
        },
        title: Text(albums[index]["name"]),
        leading: albums[index]["cover_photo"] != null
            ? Image.network(
                albums[index]["cover_photo"]["picture"],
                fit: BoxFit.fill,
                height: 70.0,
                width: 70.0,
              )
            : Container(height: 70.0, width: 70.0),
        subtitle: Text(albums[index]["count"].toString() + " Images"),
      ),
      Divider(height: 30.0)
    ]);
  }

  openAlbum(BuildContext context, int index) async{
    //final image = SlideRightRoute(FacebookPhotosPage(
    //albumId: albums[index]["id"])),
    //);#
    final source = await Navigator.push(
        context,
        PageRouteBuilder(pageBuilder: (_, animation1, animation2) {
          return FacebookPhotosPage(albumId: albums[index]["id"]);
        }, transitionsBuilder: (BuildContext _,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child) {
          return new SlideTransition(
            position: new Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        }
        ));
    //print("Album Got "+source);
    if(source != null)
      Navigator.pop(context,source);
  }
}
