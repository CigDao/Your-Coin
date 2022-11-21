import CanDB "mo:candb/CanDB";
import Entity "mo:candb/Entity";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Int32 "mo:base/Int32";
import Iter "mo:base/Iter";
import Nat32 "mo:base/Nat32";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import Response "../models/Response";
import Transaction "../models/Transaction";
import Reflection "../models/Reflection";
import Result "mo:base/Result";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Utils "../helpers/Utils";
import ULID "mo:ulid/ULID";

module {

    private type Transaction = Transaction.Transaction;
    private type Reflection = Reflection.Reflection;

    public func putReflection(db:CanDB.DB, reflection: Reflection) : async Text {
        let now = Time.now();
        let _sk = "Reflection:" # Int.toText(now);
        let attributes:[(Entity.AttributeKey, Entity.AttributeValue)] = [
            ("amount", #int(reflection.amount)),
            ("timestamp", #int(reflection.timestamp)),
        ];
        await CanDB.put(db, {
            sk = _sk;
            attributes = attributes;
        });
        _sk;
    };

    public func unwrapReflection(entity: Entity.Entity): ?Reflection {
        let { sk; attributes } = entity;
        let amount = Entity.getAttributeMapValueForKey(attributes, "amount");
        let timestamp = Entity.getAttributeMapValueForKey(attributes, "timestamp");
        switch(amount, timestamp) {
            case (
                ?(#int(amount)),
                ?(#int(timestamp)),
            ) 
            { 
                let value = Nat64.fromIntWrap(amount);
                 ?{
                    amount = Nat64.toNat(value);
                    timestamp = timestamp;
                 };
            };
            case _ { 
                null 
            }
        };
    };
}