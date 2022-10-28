import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import CA "mo:candb/CanisterActions";
import CanisterMap "mo:candb/CanisterMap";
import Utils "mo:candb/Utils";
import Buffer "mo:stable-buffer/StableBuffer";
import Http "../helpers/http";
import Response "../models/Response";
import Prim "mo:prim";
import Iter "mo:base/Iter";
import JSON "../helpers/JSON";
import Array "mo:base/Array";
import Collection "./Collection";
import Admin "mo:candb/CanDBAdmin";

shared ({caller = owner}) actor class IndexCanister() = this {

  private type JSON = JSON.JSON;
  
  /// @required stable variable (Do not delete or change)
  ///
  /// Holds the CanisterMap of PK -> CanisterIdList
  stable var pkToCanisterMap = CanisterMap.init();

  /// @required API (Do not delete or change)
  ///
  /// Get all canisters for an specific PK
  ///
  /// This method is called often by the candb-client query & update methods. 
  public shared query({caller = caller}) func getCanistersByPK(pk: Text): async [Text] {
    getCanisterIdsIfExists(pk);
  };

  /// @required function (Do not delete or change)
  ///
  /// Helper method acting as an interface for returning an empty array if no canisters
  /// exist for the given PK
  func getCanisterIdsIfExists(pk: Text): [Text] {
    switch(CanisterMap.get(pkToCanisterMap, pk)) {
      case null { [] };
      case (?canisterIdsBuffer) { Buffer.toArray(canisterIdsBuffer) } 
    }
  };

  public shared({caller = caller}) func autoScaleCollectionServiceCanister(pk: Text): async Text {
    // Auto-Scaling Authorization - if the request to auto-scale the partition is not coming from an existing canister in the partition, reject it
    if (Utils.callingCanisterOwnsPK(caller, pkToCanisterMap, pk)) {
      Debug.print("creating an additional canister for pk=" # pk);
      await createPostCollectionServiceCanister(pk, ?[owner, Principal.fromActor(this)])
    } else {
      throw Error.reject("not authorized");
    };
  };

  // Partition PostCollectionService canisters by the group passed in
  public shared({caller = creator}) func createPostCollectionServiceCanisterByGroup(group: Text): async ?Text {
    let pk = "group#" # group;
    let canisterIds = getCanisterIdsIfExists(pk);
    if (canisterIds == []) {
      ?(await createPostCollectionServiceCanister(pk, ?[owner, Principal.fromActor(this)]));
    // the partition already exists, so don't create a new canister
    } else {
      Debug.print(pk # " already exists");
      null 
    };
  };

  // Spins up a new PostCollectionService canister with the provided pk and controllers
  func createPostCollectionServiceCanister(pk: Text, controllers: ?[Principal]): async Text {
    Debug.print("creating new PostCollection service canister with pk=" # pk);
    // Pre-load 300 billion cycles for the creation of a new PostCollection Service canister
    // Note that canister creation costs 100 billion cycles, meaning there are 200 billion
    // left over for the new canister when it is created
    Cycles.add(300_000_000_000);
    let newPostCollectionServiceCanister = await Collection.Collection({
      partitionKey = pk;
      scalingOptions = {
        autoScalingHook = autoScaleCollectionServiceCanister;
        sizeLimit = #heapSize(200_000_000); // Scale out at 200MB
        // for auto-scaling testing
        //sizeLimit = #count(3); // Scale out at 3 entities inserted
      };
      owners = controllers;
    });
    let newPostCollectionServiceCanisterPrincipal = Principal.fromActor(newPostCollectionServiceCanister);
    await CA.updateCanisterSettings({
      canisterId = newPostCollectionServiceCanisterPrincipal;
      settings = {
        controllers = controllers;
        compute_allocation = ?0;
        memory_allocation = ?0;
        freezing_threshold = ?2592000;
      }
    });

    let newPostCollectionServiceCanisterId = Principal.toText(newPostCollectionServiceCanisterPrincipal);
    // After creating the new PostCollection Service canister, add it to the pkToCanisterMap
    pkToCanisterMap := CanisterMap.add(pkToCanisterMap, pk, newPostCollectionServiceCanisterId);

    Debug.print("new PostCollection service canisterId=" # newPostCollectionServiceCanisterId);
    newPostCollectionServiceCanisterId;
  };

  /// !! Do not use this method without caller authorization
  /// Upgrade user canisters in a PK range, i.e. rolling upgrades (limit is fixed at upgrading the canisters of 5 PKs per call)
  public shared({ caller = caller }) func upgradeGroupCanistersInPKRange(lowerPK: Text, upperPK: Text, wasmModule: Blob): async Admin.UpgradePKRangeResult {
    // !!! Recommend Adding to prevent anyone from being able to upgrade the wasm of your service actor canisters
    if (caller != owner) { // basic authorization
      return {
        upgradeCanisterResults = [];
        nextKey = null;
      }
    }; 
    


    // CanDB documentation on this library function - https://www.candb.canscale.dev/CanDBAdmin.html
    await Admin.upgradeCanistersInPKRange({
      canisterMap = pkToCanisterMap;
      lowerPK = lowerPK; 
      upperPK = upperPK;
      limit = 5;
      wasmModule = wasmModule;
      // the scaling options parameter that will be passed to the constructor of the upgraded canister
      scalingOptions = {
        autoScalingHook = autoScaleCollectionServiceCanister;
        sizeLimit = #heapSize(200_000_000); // Scale out at 200MB
      };
      // the owners parameter that will be passed to the constructor of the upgraded canister
      owners = ?[owner, Principal.fromActor(this)];
    });
  };

  /// !! Do not use this method without caller authorization
  /// Spins down all canisters belonging to a specific user (transfers cycles back to the index canister, and stops/deletes all canisters)
  public shared({caller = caller}) func deleteCanistersByPK(pk: Text): async ?Admin.CanisterCleanupStatusMap {
    /* !!! Recommend Adding to prevent anyone from being able to delete your service actor canisters
    if (caller != owner) return null; // authorization 
    */

    let canisterIds = getCanisterIdsIfExists(pk);
    if (canisterIds == []) {
      Debug.print("canisters with pk=" # pk # " do not exist");
      null
    } else {
      // can choose to use this statusMap for to detect failures and prompt retries if desired 
      let statusMap = await Admin.transferCyclesStopAndDeleteCanisters(canisterIds);
      pkToCanisterMap := CanisterMap.delete(pkToCanisterMap, pk);
      ?statusMap;
    };
  };

  public query func getMemorySize(): async Nat {
      let size = Prim.rts_memory_size();
      size;
  };

  public query func getHeapSize(): async Nat {
      let size = Prim.rts_heap_size();
      size;
  };

  public query func getCycles(): async Nat {
      Cycles.balance();
  };

  private func _getMemorySize(): Nat {
      let size = Prim.rts_memory_size();
      size;
  };

  private func _getHeapSize(): Nat {
      let size = Prim.rts_heap_size();
      size;
  };

  private func _getCycles(): Nat {
      Cycles.balance();
  };

  public query func http_request(request: Http.Request) : async Http.Response {
    let path = Iter.toArray(Text.tokens(request.url, #text("/")));
    if (path.size() == 1) {
      switch(path[0]){
          case("getMemorySize") return _natResponse(_getMemorySize());
          case("getHeapSize") return _natResponse(_getHeapSize());
          case("getCycles") return _natResponse(_getCycles());
          case(_) return return Http.NOT_FOUND();
      };
    }else if(path.size() == 2){ 
      switch(path[0]){
          case("pk") return _pkResponse(path[1]);
          case(_) return return Http.NOT_FOUND();
      };
    }else {
        return Http.BAD_REQUEST();
    }
  };

  private func _natResponse(value : Nat): Http.Response {
      let json = #Number(value);
      let blob = Text.encodeUtf8(JSON.show(json));
      let response: Http.Response = {
          status_code        = 200;
          headers            = [("Content-Type", "application/json")];
          body               = blob;
          streaming_strategy = null;
      };
  };

  private func _pkResponse(group : Text): Http.Response {
      let pk = "group#" # group;
      let result = getCanisterIdsIfExists(pk);
      var canisters:[JSON] = [];
      for(canister in result.vals()){
        canisters := Array.append(canisters,[#String(canister)]);
      };
      assert(canisters.size() > 0);
      let json = #Array(canisters);
      let blob = Text.encodeUtf8(JSON.show(json));
      let response: Http.Response = {
          status_code        = 200;
          headers            = [("Content-Type", "application/json")];
          body               = blob;
          streaming_strategy = null;
      };
  };
}