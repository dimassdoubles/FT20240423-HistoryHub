import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:history_hub_v2/app/core/constants/base_url.dart';
import 'package:history_hub_v2/app/core/constants/supabase/sp_functions.dart';
import 'package:history_hub_v2/app/core/constants/supabase/sp_storages.dart';
import 'package:history_hub_v2/app/core/constants/supabase/sp_tables.dart';
import 'package:history_hub_v2/app/data/datasources/local_datasource.dart';
import 'package:history_hub_v2/app/data/models/auth/kabupaten_model.dart';
import 'package:history_hub_v2/app/data/models/auth/kecamatan_model.dart';
import 'package:history_hub_v2/app/data/models/auth/kelurahan_model.dart';
import 'package:history_hub_v2/app/data/models/auth/user_model.dart';
import 'package:history_hub_v2/app/data/models/event/event_model.dart';
import 'package:history_hub_v2/app/data/models/order/order_model.dart';
import 'package:history_hub_v2/app/data/models/post/comment_model.dart';
import 'package:history_hub_v2/app/data/models/post/post_model.dart';
import 'package:history_hub_v2/app/data/models/profile/user_profile_model.dart';
import 'package:history_hub_v2/app/data/params/auth/register_user_params.dart';
import 'package:history_hub_v2/app/data/params/event/create_event_params.dart';
import 'package:history_hub_v2/app/data/params/event/get_list_event_params.dart';
import 'package:history_hub_v2/app/data/params/order/create_new_order_params.dart';
import 'package:history_hub_v2/app/data/params/order/get_list_order_params.dart';
import 'package:history_hub_v2/app/data/params/post/create_post_params.dart';
import 'package:history_hub_v2/app/data/params/post/get_list_post_params.dart';
import 'package:history_hub_v2/app/data/params/post/get_user_liked_list_post_params.dart';
import 'package:history_hub_v2/app/data/params/post/get_user_list_post_params.dart';
import 'package:history_hub_v2/app/data/params/profile/edit_user_profile_params.dart';
import 'package:history_hub_v2/app/modules/home/home_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

abstract class AppDatasource {
  // auth
  Future<void> registerUser(RegisterUserParams params);
  Future<UserModel> login(String email, String password);
  Future<void> logout();
  Future<List<KabupatenModel>> getListKabupaten();
  Future<List<KecamatanModel>> getListKecamatan(int kabupatenId);
  Future<List<KelurahanModel>> getListKelurahan(int kecamatanId);
  Future<UserModel?> getCurrentUser();

  // post
  Future<List<PostModel>> getListPost(GetListPostParams params);
  Future<void> createPost(CreatePostParams params);
  Future<void> like(String postId);
  Future<void> comment(String postId, String comment);
  Future<List<CommentModel>> geListComment(String postId);
  Future<List<PostModel>> getUserListPost(
    GetUserListPostParams params,
  );
  Future<List<PostModel>> getUserLikedListPost(
    GetUserLikedListPostParams params,
  );
  Future<void> deletePost(String postId);

  // event
  Future<void> createEvent(CreateEventParams params);
  Future<List<EventModel>> getListEvent(
    GetListEventParams params, // intial page = 0
  );
  Future<EventModel> getEvent(String id);

  // transactions
  Future<OrderModel> creaetNewOrder(CreateNewOrderParams params);
  Future<List<OrderModel>> getListOrder(GetListOrderParams params);

  // profiles
  Future<UserProfileModel> getUserProfile(String userId);
  Future<UserProfileModel> editUserProfile(EditUserProfileParams params);

  // member
  Future<List<UserModel>> getListMember(String keyword);
  Future<void> removeAdmin(List<String> listUserId);
  Future<void> addAdmin(List<String> listUserId);
  Future<void> allowToPost(List<String> listUserId);
  Future<void> prohibitToPost(List<String> listUserId);
}

class AppDatasourceImpl implements AppDatasource {
  final LocalDatasource _localDatasource;

  AppDatasourceImpl(this._localDatasource) {
    _supabaseClient = Supabase.instance.client;
  }

  late final SupabaseClient _supabaseClient;

  @override
  Future<void> createEvent(CreateEventParams params) async {
    String imageUrl = "";
    const uuid = Uuid();
    final eventId = uuid.v4();

    if (params.image != null) {
      debugPrint('image path: ${params.image!.path}');

      String fileName =
          "$eventId-01${path.extension(params.image!.path)}"; // 01 adalah urutan photo
      debugPrint(fileName);
      final uploadPath = '${params.userId}/$fileName';
      imageUrl = await _supabaseClient.storage.from(SpStorages.event).upload(
            uploadPath,
            params.image!,
          );

      debugPrint('imageUrl: $imageUrl');
    }

    await _supabaseClient.rpc(SpFunctions.createEvent, params: {
      'p_id': eventId,
      'p_image_url': '$baseUrl/storage/v1/object/public/$imageUrl',
      ...params.toMap(),
    });
  }

  @override
  Future<void> createPost(CreatePostParams params) async {
    String imageUrl = "";
    const uuid = Uuid();
    final postId = uuid.v4();

    if (params.image != null) {
      debugPrint('image path: ${params.image!.path}');

      String fileName =
          "$postId-01${path.extension(params.image!.path)}"; // 01 adalah urutan photo
      debugPrint(fileName);
      final uploadPath = '${params.userId}/$fileName';
      imageUrl = await _supabaseClient.storage.from(SpStorages.post).upload(
            uploadPath,
            params.image!,
          );

      debugPrint('imageUrl: $imageUrl');
    }

    await _supabaseClient.rpc(SpFunctions.createPost, params: {
      'p_id': postId,
      'p_image_url': '$baseUrl/storage/v1/object/public/$imageUrl',
      ...params.toMap(),
    });
  }

  @override
  Future<UserModel?> getCurrentUser() {
    // TODO: implement getCurrentUser
    throw UnimplementedError();
  }

  @override
  Future<List<KabupatenModel>> getListKabupaten() async {
    final response = await _supabaseClient.rpc(SpFunctions.getListKabupaten);
    return List<KabupatenModel>.from(
      response.map((json) => KabupatenModel.fromJson(json)),
    );
  }

  @override
  Future<List<KecamatanModel>> getListKecamatan(int kabupatenId) async {
    final response =
        await _supabaseClient.rpc(SpFunctions.getListKecamatan, params: {
      "kabupaten_id": kabupatenId,
    });
    return List<KecamatanModel>.from(
      response.map((json) => KecamatanModel.fromJson(json)),
    );
  }

  @override
  Future<List<KelurahanModel>> getListKelurahan(int kecamatanId) async {
    final response =
        await _supabaseClient.rpc(SpFunctions.getListKelurahan, params: {
      "kecamatan_id": kecamatanId,
    });
    return List<KelurahanModel>.from(
      response.map((json) => KelurahanModel.fromJson(json)),
    );
  }

  @override
  Future<List<PostModel>> getListPost(GetListPostParams params) async {
    debugPrint('login');
    final response = await _supabaseClient.rpc(
      SpFunctions.getListPost,
      params: params.toJson(),
    );
    return List<PostModel>.from(
      response.map((json) => PostModel.fromJson(json)),
    );
  }

  @override
  Future<UserModel> login(
    String email,
    String password,
  ) async {
    debugPrint('login');
    await _supabaseClient.auth
        .signInWithPassword(email: email, password: password);
    final userProfile = await _supabaseClient.rpc(SpFunctions.getMyUserProfile);
    _localDatasource.login(UserModel.fromJson(userProfile.first));
    return UserModel.fromJson(userProfile.first);
  }

  @override
  Future<void> registerUser(RegisterUserParams params) async {
    final response = await _supabaseClient.auth.signUp(
      email: params.email,
      password: params.password,
    );

    final userId = response.user!.id;
    await _supabaseClient.from(SpTables.userProfiles).insert({
      'user_id': userId,
      ...params.toMap(),
    });
  }

  @override
  Future<void> like(String postId) async {
    await _supabaseClient.rpc(
      SpFunctions.likePost,
      params: {
        'post_id': postId,
      },
    );

    return;
  }

  @override
  Future<void> comment(String postId, String comment) async {
    await _supabaseClient.rpc(
      SpFunctions.commentPost,
      params: {
        'post_id': postId,
        'content': comment,
      },
    );

    return;
  }

  @override
  Future<List<CommentModel>> geListComment(String postId) async {
    final response = await _supabaseClient.rpc(
      SpFunctions.getListComment,
      params: {
        'input_post_id': postId,
      },
    );

    return List<CommentModel>.from(
      response.map((json) => CommentModel.fromJson(json)),
    );
  }

  @override
  Future<List<EventModel>> getListEvent(GetListEventParams params) async {
    final response = await _supabaseClient.rpc(
      SpFunctions.getListEvent,
      params: params.toJson(),
    );

    return List<EventModel>.from(
      response.map((json) => EventModel.fromJson(json)),
    );
  }

  @override
  Future<OrderModel> creaetNewOrder(CreateNewOrderParams params) async {
    final response = await _supabaseClient.rpc(
      SpFunctions.createNewOrder,
      params: params.toJson(),
    );

    return OrderModel.fromJson(response.first);
  }

  @override
  Future<List<OrderModel>> getListOrder(GetListOrderParams params) async {
    final response = await _supabaseClient.rpc(
      SpFunctions.getListOrder,
      params: params.toJson(),
    );

    return List<OrderModel>.from(
      response.map((json) => OrderModel.fromJson(json)),
    );
  }

  @override
  Future<void> deletePost(String postId) {
    // TODO: implement deletePost
    throw UnimplementedError();
  }

  @override
  Future<UserProfileModel> editUserProfile(EditUserProfileParams params) async {
    String imageUrl = '';

    if (params.image != null) {
      String fileName =
          "${DateTime.now().millisecondsSinceEpoch}${path.extension(params.image!.path)}"; // 01 adalah urutan photo
      debugPrint(fileName);
      final uploadPath = '${params.userId}/$fileName';
      debugPrint('upload gambar');
      imageUrl = await _supabaseClient.storage.from(SpStorages.avatar).upload(
            uploadPath,
            File(params.image!.path),
          );
    }

    final response = await _supabaseClient.rpc(
      params.image != null
          ? SpFunctions.editUserProfile
          : SpFunctions.editUserProfileNoImage,
      params: params.image != null
          ? {
              'p_avatar_url': '$baseUrl/storage/v1/object/public/$imageUrl',
              ...params.toJson(),
            }
          : params.toJson(),
    );

    _localDatasource.login(UserModel.fromJson(response.first));

    try {
      Get.find<HomeController>().currentUser =
          UserModel.fromJson(response.first);
    } catch (_) {}

    return UserProfileModel.fromJson(response.first);
  }

  @override
  Future<List<PostModel>> getUserLikedListPost(
      GetUserLikedListPostParams params) {
    // TODO: implement getUserLikedListPost
    throw UnimplementedError();
  }

  @override
  Future<List<PostModel>> getUserListPost(GetUserListPostParams params) {
    // TODO: implement getUserListPost
    throw UnimplementedError();
  }

  @override
  Future<UserProfileModel> getUserProfile(String userId) async {
    final userProfile =
        await _supabaseClient.rpc(SpFunctions.getUserProfile, params: {
      "p_user_id": userId,
    });
    debugPrint('Sampai sini bro');
    return UserProfileModel.fromJson(userProfile.first);
  }

  @override
  Future<void> logout() async {
    _localDatasource.logout();
    _supabaseClient.auth.signOut();
  }

  @override
  Future<List<UserModel>> getListMember(String keyword) async {
    final response =
        await _supabaseClient.rpc(SpFunctions.getListMember, params: {
      "p_keyword": keyword,
    });

    return List<UserModel>.from(
      response.map((json) => UserModel.fromJson(json)),
    );
  }

  @override
  Future<void> addAdmin(List<String> listUserId) async {
    await _supabaseClient.rpc(SpFunctions.addAdmin, params: {
      "p_list_user_id": listUserId,
    });
  }

  @override
  Future<void> allowToPost(List<String> listUserId) async {
    await _supabaseClient.rpc(SpFunctions.allowtoPost, params: {
      "p_list_user_id": listUserId,
    });
  }

  @override
  Future<void> prohibitToPost(List<String> listUserId) async {
    await _supabaseClient.rpc(SpFunctions.prohibitToPost, params: {
      "p_list_user_id": listUserId,
    });
  }

  @override
  Future<void> removeAdmin(List<String> listUserId) async {
    await _supabaseClient.rpc(SpFunctions.removeAdmin, params: {
      "p_list_user_id": listUserId,
    });
  }

  @override
  Future<EventModel> getEvent(String id) async {
    final response = await _supabaseClient.rpc(
      SpFunctions.getEvent,
      params: {"p_id": id},
    );

    return EventModel.fromJson(response.first);
  }
}
