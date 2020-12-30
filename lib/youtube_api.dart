import 'dart:convert';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'youtube_data.dart';
import 'save_file.dart';

http.Client client = new http.Client();

class YoutubeApi {
  static Future<String> getVideoInfoDictionary(String videoId) async {
    var url =
        'https://www.youtube.com/get_video_info?&video_id=${videoId}&el=detailpage';
    var raw = (await client.get(url)).body;
    var response = Uri.splitQueryString(raw);

    var playerResponseJson = json.decode(response['player_response']);
    var streamingData = playerResponseJson['streamingData'];
    var formats = streamingData['formats'];
    var videoUrl = formats[formats.length - 1];

    return videoUrl["url"];
  }

  static Future<Map<dynamic, dynamic>> getVideoInfoDetails(
      {String query, String key, String pageToken, String sp}) async {
    Map<String, dynamic> resultData = {'results': {}};

    var body = {
      'context': const {
        'client': {
          'hl': 'en',
          'clientName': 'WEB',
          'clientVersion': '2.20200911.04.00'
        }
      },
      'continuation': pageToken
    };
    print(json.encode(body));
    if (key != null) {
      final http.Response response = await http.post(
        'https://www.youtube.com/youtubei/v1/search?key=$key',
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        print(json.decode(response.body));
        savetoFile(response.body);
        return resultData;
      } else {
        return resultData;
      }
    } else {
      var url =
          "https://www.youtube.com/results?search_query=redkit&sp=EgIQAQ%253D%253D";

      var raw = (await client.get(url)).body;
      var root = parser.parse(raw);
      final _apiKeyExp = RegExp(r'"INNERTUBE_API_KEY":"(\w+?)"');

      ///
      String apiKey = _apiKeyExp
          .firstMatch(root
              .querySelectorAll('script')
              .firstWhere((e) => e.text.contains('INNERTUBE_API_KEY'))
              .text)
          .group(1);

      final scriptText = root
          .querySelectorAll('script')
          .map((e) => e.text)
          .toList(growable: false);

      var initialDataText = scriptText.firstWhere(
          (e) => e.contains('window["ytInitialData"] ='),
          orElse: () => null);

      initialDataText = scriptText.firstWhere(
          (e) => e.contains('var ytInitialData = '),
          orElse: () => null);

      String _matchJson(String str) {
        var bracketCount = 0;
        int lastI;
        for (var i = 0; i < str.length; i++) {
          lastI = i;
          if (str[i] == '{') {
            bracketCount++;
          } else if (str[i] == '}') {
            bracketCount--;
          } else if (str[i] == ';') {
            if (bracketCount == 0) {
              return str.substring(0, i);
            }
          }
        }
        return str.substring(0, lastI + 1);
      }

      String _extractJson(String html, String separator) {
        return _matchJson(
            html.substring(html.indexOf(separator) + separator.length));
      }

      var jsonData;
      if (initialDataText != null) {
        jsonData =
            json.decode(_extractJson(initialDataText, 'var ytInitialData = '));
      }
      var estimatedResults = YoutubeData.fromJson(jsonData).estimatedResults;

      var contents = YoutubeData.fromJson(jsonData)
          .contents
          .twoColumnSearchResultsRenderer
          .primaryContents
          .sectionListRenderer
          .contents
          .first
          .itemSectionRenderer
          .contents;
      var nextPageToken = YoutubeData.fromJson(jsonData)
          .contents
          .twoColumnSearchResultsRenderer
          .primaryContents
          .sectionListRenderer
          .contents
          .last
          .continuationItemRenderer
          .continuationEndpoint
          .continuationCommand
          .token;

      resultData = {
        'results': {},
        'version': '1.0',
        'parser': 'YotubeParser',
        'key': apiKey,
        'estimatedResults': estimatedResults ?? 0,
        'nextPageToken': nextPageToken ?? "",
      };

      for (var i = 0; i < contents.length; i++) {
        var renderer = contents[i].videoRenderer;
        Map<String, dynamic> video = {
          'video': {
            'id': renderer.videoId,
            'title': renderer.title.runs.first.text ?? "",
            'url':
                'https://www.youtube.com${renderer.navigationEndpoint.commandMetadata.webCommandMetadata.url}',
            'duration': renderer.lengthText.simpleText ?? "Live",
            'snippet': renderer.descriptionSnippet ?? "",
            'upload_date': renderer.publishedTimeText.simpleText ?? "Live",
            'thumbnail_src': renderer.thumbnail.thumbnails.last.url,
            'views': renderer.viewCountText.simpleText ?? '0',
            'username': renderer.ownerText.runs.first.text ?? "",
            'channel_url':
                'https://www.youtube.com${renderer.ownerText.runs.first.navigationEndpoint.commandMetadata.webCommandMetadata.url}' ??
                    "",
            'verified': false,
          }
        };

        resultData["results"] = video;
      }
    }
    print(resultData);
    return resultData;
  }
}