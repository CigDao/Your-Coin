import DatabaseBatch "../helpers/DatabaseBatch";
import ReflectionDatabaseBatch "../helpers/ReflectionDatabaseBatch";
import Transaction "../models/Transaction";
import Reflection "../models/Reflection";
import Http "../helpers/http";
import Response "../models/Response";
import JSON "../helpers/JSON";
import Constants "../Constants";
import Error "mo:base/Error";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";

actor  {

    private var log = "";

    private type Reflection = Reflection.Reflection;
    private type Transaction = Transaction.Transaction;
    private type JSON = JSON.JSON;

    public shared({caller}) func putTransactions(transactions:[Transaction]): async() {
        log := "transaction database started work " #Nat.toText(transactions.size());
        let tokenCanister = Principal.fromText(Constants.dip20Canister);
        assert(caller == tokenCanister);
        try{
            await DatabaseBatch.batchAwaitAllCanisterStatuses(transactions, 100);
            log := "database Worked " #Nat.toText(transactions.size());
        }catch(e){
            log := "reflection transaction:" #"Size: " #Nat.toText(transactions.size()) #Error.message(e);
        };
    };

    public shared({caller}) func putReflections(reflections:[Reflection]): async() {
        log := "reflection database started work " #Nat.toText(reflections.size());
        let tokenCanister = Principal.fromText(Constants.dip20Canister);
        assert(caller == tokenCanister);
        try{
            await ReflectionDatabaseBatch.batchAwaitAllCanisterStatuses(reflections, 100);
            log := "database Worked " #Nat.toText(reflections.size());
        }catch(e){
            log := "refelction:" #"Size: " #Nat.toText(reflections.size()) #Error.message(e) ;
        };
    };

    public query func http_request(request : Http.Request) : async Http.Response {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));
        if (path.size() == 1) {
            switch (path[0]) {
                case ("log") return _textResponse(log);
                case (_) return return Http.BAD_REQUEST();
            };
        }else {
            return Http.BAD_REQUEST();
        };
    };

    private func _natResponse(value : Nat) : Http.Response {
        let json = #Number(value);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };

    private func _textResponse(value : Text) : Http.Response {
        let json = #String(value);
        let blob = Text.encodeUtf8(JSON.show(json));
        let response : Http.Response = {
            status_code = 200;
            headers = [("Content-Type", "application/json")];
            body = blob;
            streaming_strategy = null;
        };
    };
}