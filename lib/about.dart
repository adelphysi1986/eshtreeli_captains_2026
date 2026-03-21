import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

Future<List<Album>> fetchAlbum() async {
  final response =
      await http.get(Uri.parse('https://localhost:5000/api/abouts'));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final List<Album> list = [];
    for (var i = 0; i < data['data'].length; i++) {
      final entry = data['data'][i];
      list.add(Album.fromJson(entry));
    }
    return list;
  } else {
    throw Exception('Failed to load album');
  }
}

class Album {
  final String about_title;
  final String about_description;
  final String date;

  const Album(
      {required this.about_title,
      required this.about_description,
      required this.date});

  factory Album.fromJson(Map<String, dynamic> json) {
    //لفك الجيسون
    return Album(
        about_title: json['about_title'],
        about_description: json['about_description'],
        date: json['updated_at']);
  }
}

class about extends StatefulWidget {
  const about({super.key});

  @override
  State<about> createState() => _aboutState();
}

class _aboutState extends State<about> {
  late Future<List<Album>> futureAlbum;

  @override
  void initState() {
    super.initState();
    futureAlbum = fetchAlbum();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: const Text(
            'حول التطبيق',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      body: Center(
          child: FutureBuilder<List<Album>>(
              future: futureAlbum,
              builder: (context, AsyncSnapshot snapshot) {
                if (snapshot.hasData) {
                  return ListView.builder(
                    itemBuilder: (context, index) {
                      Album data = snapshot.data?[index];
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                      padding: EdgeInsets.all(10),
                                      alignment: Alignment.topRight,
                                      child: Text(
                                        data.date + ' :حدثت بتاريخ ',
                                        style: TextStyle(color: Colors.red),
                                      )),
                                  Container(
                                      padding: EdgeInsets.all(10),
                                      alignment: Alignment.topRight,
                                      child: Text(
                                        data.about_title,
                                      ))
                                ]),
                            Container(
                              padding: EdgeInsets.all(10),
                              alignment: Alignment.topRight,
                              child: Text(
                                data.about_description,
                                textAlign: TextAlign.right,
                              ),
                            )
                          ]);
                    },
                    itemCount: snapshot.data!.length,
                  );
                } else if (snapshot.hasError) {
                  return Text('Eroor:${snapshot.error}');
                }
                return const CircularProgressIndicator();
              })),
    );
  }
}
