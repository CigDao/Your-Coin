/**
 * Module     : token.mo
 * Copyright  : 2021 DFinance Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : DFinance Team <hello@dfinance.ai>
 * Stability  : Experimental
 */

import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Types "../models/types";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Float "mo:base/Float";
import Array "mo:base/Array";
import List "mo:base/List";
import Option "mo:base/Option";
import Blob "mo:base/Blob";
import Order "mo:base/Order";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Result "mo:base/Result";
import Text "mo:base/Text";
import ExperimentalCycles "mo:base/ExperimentalCycles";
import Cap "./cap/Cap";
import Root "./cap/Root";
import Holder "../models/Holder";
import Constants "../Constants";
import CommunityService "../services/CommunityService";
import DatabaseService "../services/DatabaseService";
import ReflectionDatabaseService "../services/ReflectionDatabaseService";
import Utils "../helpers/Utils";
import SHA256 "mo:crypto/SHA/SHA256";
import JSON "../helpers/JSON";
import Transaction "../models/Transaction";
import Http "../helpers/http";
import Response "../models/Response";
import Reflection "../models/Reflection";

shared(msg) actor class Token(
    _logo: Text,
    _name: Text,
    _symbol: Text,
    _decimals: Nat8,
    _totalSupply: Nat,
    _owner: Principal,
    _fee: Nat,
    ) = this {

    private type Reflection = Reflection.Reflection;
    type Holder = Holder.Holder;
    type Operation = Types.Operation;
    type TransactionStatus = Types.TransactionStatus;
    type TxRecord = Types.TxRecord;
    type Metadata = {
        logo : Text;
        name : Text;
        symbol : Text;
        decimals : Nat8;
        totalSupply : Nat;
        owner : Principal;
        fee : Nat;
    };
    // returns tx index or error msg
    public type TxReceipt = Types.TxReceipt;
    private type JSON = JSON.JSON;
    private type Transaction = Transaction.Transaction;
    private stable var transactionPercentage:Float = 0.11;
    private stable var owner_ : Principal = _owner;
    private stable var logo_ : Text = _logo;
    private stable var name_ : Text = _name;
    private stable var decimals_ : Nat8 = _decimals;
    private stable var symbol_ : Text = _symbol;
    private stable var totalSupply_ : Nat = _totalSupply;
    private stable var blackhole : Principal = Principal.fromText("aaaaa-aa");
    private stable var feeTo : Principal = owner_;
    private stable var fee : Nat = _fee;
    private stable var balanceEntries : [(Principal, Nat)] = [];
    private stable var allowanceEntries : [(Principal, [(Principal, Nat)])] = [];
    private var balances = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
    private var allowances = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Nat>>(1, Principal.equal, Principal.hash);
    private var wallet = Principal.fromText(Constants.wallet);
    private var burnWallet = Principal.fromText(Constants.burnWallet);
    private var marketWallet = Principal.fromText(Constants.marketWallet);
    let burnAmount = Utils.natToFloat(Nat.div(totalSupply_,2));
    let walletAmount = Float.mul(burnAmount,0.4);
    let marketWalletAmount = Float.mul(burnAmount,0.6);
    balances.put(burnWallet,  Utils.floatToNat(burnAmount));
    balances.put(wallet, Utils.floatToNat(walletAmount));
    balances.put(marketWallet, Utils.floatToNat(marketWalletAmount));
    private stable let genesis : TxRecord = {
        caller = ?owner_;
        op = #mint;
        index = 0;
        from = blackhole;
        to = wallet;
        amount = totalSupply_;
        fee = 0;
        timestamp = Time.now();
        status = #succeeded;
    };
    
    private stable var txcounter: Nat = 0;
    private var cap: ?Cap.Cap = null;
    private func addRecord(
        caller: Principal,
        op: Text, 
        details: [(Text, Root.DetailValue)]
        ): async () {
        let c = switch(cap) {
            case(?c) { c };
            case(_) { Cap.Cap(Principal.fromActor(this), 2_000_000_000_000) };
        };
        cap := ?c;
        let record: Root.IndefiniteEvent = {
            operation = op;
            details = details;
            caller = caller;
        };
        // don't wait for result, faster
        ignore c.insert(record);
    };

    private func _chargeFee(from: Principal, fee: Nat) {
        if(fee > 0) {
            _transfer(from, feeTo, fee);
        };
    };

    private func _transfer(from: Principal, to: Principal, value: Nat) {
        let from_balance = _balanceOf(from);
        let from_balance_new : Nat = from_balance - value;
        if (from_balance_new != 0) { balances.put(from, from_balance_new); }
        else { balances.delete(from); };

        let to_balance = _balanceOf(to);
        let to_balance_new : Nat = to_balance + value;
        if (to_balance_new != 0) { balances.put(to, to_balance_new); };
    };

    private func _putTransacton(amount:Int, sender:Text, receiver:Text, tax:Int, transactionType:Text) : async Text {
        let now = Time.now();

        let _transaction = {
            sender = sender;
            receiver = receiver;
            amount = amount;
            fee = tax;
            timeStamp = now;
            hash = "";
            transactionType = transactionType;
        };

        let hash = Utils._transactionToHash(_transaction);

        let transaction = {
            sender = sender;
            receiver = receiver;
            amount = amount;
            fee = tax;
            timeStamp = now;
            hash = hash;
            transactionType = transactionType;
        };

        let _canisters = await DatabaseService.canister.getCanistersByPK("group#ledger");
        let canisters = List.fromArray<Text>(_canisters);
        let exist = List.last(canisters);

        switch(exist){
            case(?exist){
                return await DatabaseService.putTransaction(exist,transaction);
            };
            case(null){
                return "";
            };
        };
    };

    private func _putReflection(amount:Nat) : async Text {
        let now = Time.now();

        let reflection = {
            amount = amount;
            timestamp = now;
        };

        let _canisters = await ReflectionDatabaseService.canister.getCanistersByPK("group#ledger");
        let canisters = List.fromArray<Text>(_canisters);
        let exist = List.last(canisters);

        switch(exist){
            case(?exist){
                return await ReflectionDatabaseService.putReflection(exist,reflection);
            };
            case(null){
                return "";
            };
        };
    };

    private func _balanceOf(who: Principal) : Nat {
        switch (balances.get(who)) {
            case (?balance) { return balance; };
            case (_) { return 0; };
        }
    };

    private func _allowance(owner: Principal, spender: Principal) : Nat {
        switch(allowances.get(owner)) {
            case (?allowance_owner) {
                switch(allowance_owner.get(spender)) {
                    case (?allowance) { return allowance; };
                    case (_) { return 0; };
                }
            };
            case (_) { return 0; };
        }
    };

    private func u64(i: Nat): Nat64 {
        Nat64.fromNat(i)
    };

    /*
    *   Core interfaces:
    *       update calls:
    *           transfer/transferFrom/approve
    *       query calls:
    *           logo/name/symbol/decimal/totalSupply/balanceOf/allowance/getMetadata
    *           historySize/getTransaction/getTransactions
    */

    public shared({caller}) func updateTransactionPercentage(value:Float): async() {
        assert(caller == Principal.fromText(Constants.daoCanister));
        transactionPercentage := value;
    };

    public shared({caller})func chargeTax(sender:Principal,amount:Nat) : async TxReceipt {
        let daoCanister = Principal.fromText(Constants.daoCanister);
        assert(daoCanister == caller);
        await _chargeTax(sender,amount);
    };

    private func _chargeTax(sender:Principal,amount:Nat) : async TxReceipt {
        var holders:[Holder] = [];
        let to = Principal.fromText(Constants.communityCanister);
        if (_balanceOf(sender) < amount) { return #Err(#InsufficientBalance); };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        _transfer(sender, to, amount);
        for((principal,amount) in balances.entries()) {
            let _holder:Holder = {
                holder = Principal.toText(principal);
                amount = amount;
                receipt = #Err(#Other(""));
            };
            holders := Array.append(holders,[_holder]);
        };

        ignore CommunityService.distribute(amount,holders);
        let hash = await _putTransacton(amount, Principal.toText(sender), Principal.toText(to), 0, "tax");
        ignore addRecord(
            msg.caller, "transfer",
            [
                ("to", #Principal(to)),
                ("amount", #U64(u64(amount))),
                ("tax", #U64(u64(0))),
                ("hash", #Text(hash))
            ]
        );
        return #Ok(_txcounter);
    };

    private func _transactionToHash(transaction:Transaction): Text {
        let json = Utils._transactionToJson(transaction);
        JSON.show(json);
    };

    /// Transfers value amount of tokens to Principal to.

    public shared(msg) func communityTransfer(to: Principal, value: Nat) : async TxReceipt {
        let communityCanister = Principal.fromText(Constants.communityCanister);
        if(msg.caller != communityCanister) {return #Err(#Unauthorized);};
        if (_balanceOf(msg.caller) < value) { return #Err(#InsufficientBalance); };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        _transfer(msg.caller, to, value);
        let hash = await _putTransacton(value, Constants.communityCanister, Principal.toText(to), 0, "dao");
        ignore addRecord(
            msg.caller, "transfer",
            [
                ("to", #Principal(to)),
                ("amount", #U64(u64(value))),
                ("tax", #U64(u64(0))),
                ("hash", #Text(hash))
            ]
        );
        return #Ok(_txcounter);
    };

    public shared(msg) func transfer(to: Principal, value: Nat) : async TxReceipt {
        let _tax:Float = Float.mul(Utils.natToFloat(value), transactionPercentage);
        let tax = Utils.floatToNat(_tax);
        if (_balanceOf(msg.caller) < value + fee) { return #Err(#InsufficientBalance); };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        ignore _chargeTax(msg.caller, tax);
        _chargeFee(msg.caller, fee);
        _transfer(msg.caller, to, value - tax);
        let hash = await _putTransacton(value, Principal.toText(msg.caller), Principal.toText(to), tax, "transfer");
        ignore addRecord(
            msg.caller, "transfer",
            [
                ("to", #Principal(to)),
                ("amount", #U64(u64(value - tax))),
                ("tax", #U64(u64(tax))),
                ("hash", #Text(hash))
            ]
        );
        return #Ok(_txcounter);
    };

    public shared(msg) func bulkTransfer(holders:[Holder]) : async [Holder] {
        var response:[Holder] = [];
        let communityCanister = Principal.fromText(Constants.communityCanister);
        if(msg.caller != communityCanister) {return response};
        for(value in holders.vals()){
            if (_balanceOf(msg.caller) < value.amount) { return response };
            txcounter := txcounter + 1;
            var _txcounter = txcounter;
            _transfer(msg.caller, Principal.fromText(value.holder), value.amount);
            let hash = await _putTransacton(value.amount, Constants.communityCanister, value.holder, 0, "reflections");
            ignore _putReflection(value.amount);
            ignore addRecord(
                msg.caller, "transfer",
                [
                    ("to", #Principal(Principal.fromText(value.holder))),
                    ("amount", #U64(u64(value.amount))),
                    ("hash", #Text(hash))
                ]
            );
            let _holder:Holder = {
                holder = value.holder;
                amount = value.amount;
                receipt = #Ok(_txcounter);
            };
            response := Array.append(response,[_holder]);
        };
        return response;
    };

    /// Transfers value amount of tokens from Principal from to Principal to.
    public shared(msg) func transferFrom(from: Principal, to: Principal, value: Nat) : async TxReceipt {
        let _tax:Float = Float.mul(Utils.natToFloat(value), transactionPercentage);
        let tax = Utils.floatToNat(_tax);
        if (_balanceOf(from) < value + fee) { return #Err(#InsufficientBalance); };
        let allowed : Nat = _allowance(from, msg.caller);
        if (allowed < value + fee) { return #Err(#InsufficientAllowance); };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        ignore await _chargeTax(msg.caller, tax);
        _chargeFee(from, fee);
        _transfer(from, to, value);
        let hash = await _putTransacton(value, Principal.toText(from), Principal.toText(to), tax, "tranfer");
        let allowed_new : Nat = allowed - value - fee;
        if (allowed_new != 0) {
            let allowance_from = Types.unwrap(allowances.get(from));
            allowance_from.put(msg.caller, allowed_new);
            allowances.put(from, allowance_from);
        } else {
            if (allowed != 0) {
                let allowance_from = Types.unwrap(allowances.get(from));
                allowance_from.delete(msg.caller);
                if (allowance_from.size() == 0) { allowances.delete(from); }
                else { allowances.put(from, allowance_from); };
            };
        };
        ignore addRecord(
            msg.caller, "transferFrom",
            [
                ("from", #Principal(from)),
                ("to", #Principal(to)),
                ("amount", #U64(u64(value))),
                ("tax", #U64(u64(tax))),
                ("hash", #Text(hash))
            ]
        );
        return #Ok(_txcounter);
    };

    /// Allows spender to withdraw from your account multiple times, up to the value amount.
    /// If this function is called again it overwrites the current allowance with value.
    public shared(msg) func approve(spender: Principal, value: Nat) : async TxReceipt {
        if(_balanceOf(msg.caller) < fee) { return #Err(#InsufficientBalance); };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        _chargeFee(msg.caller, fee);
        let v = value + fee;
        if (value == 0 and Option.isSome(allowances.get(msg.caller))) {
            let allowance_caller = Types.unwrap(allowances.get(msg.caller));
            allowance_caller.delete(spender);
            if (allowance_caller.size() == 0) { allowances.delete(msg.caller); }
            else { allowances.put(msg.caller, allowance_caller); };
        } else if (value != 0 and Option.isNull(allowances.get(msg.caller))) {
            var temp = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);
            temp.put(spender, v);
            allowances.put(msg.caller, temp);
        } else if (value != 0 and Option.isSome(allowances.get(msg.caller))) {
            let allowance_caller = Types.unwrap(allowances.get(msg.caller));
            allowance_caller.put(spender, v);
            allowances.put(msg.caller, allowance_caller);
        };
        ignore addRecord(
            msg.caller, "approve",
            [
                ("to", #Principal(spender)),
                ("amount", #U64(u64(value))),
                ("fee", #U64(u64(fee)))
            ]
        );
        return #Ok(_txcounter);
    };

    public shared(msg) func mint(to: Principal, value: Nat): async TxReceipt {
        if(msg.caller != owner_) {
            return #Err(#Unauthorized);
        };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        let to_balance = _balanceOf(to);
        totalSupply_ += value;
        balances.put(to, to_balance + value);
        ignore addRecord(
            msg.caller, "mint",
            [
                ("to", #Principal(to)),
                ("amount", #U64(u64(value))),
                ("fee", #U64(u64(0)))
            ]
        );
        return #Ok(txcounter);
    };

    public shared(msg) func burn(amount: Nat): async TxReceipt {
        let from_balance = _balanceOf(msg.caller);
        if(from_balance < amount) {
            return #Err(#InsufficientBalance);
        };
        txcounter := txcounter + 1;
        var _txcounter = txcounter;
        totalSupply_ -= amount;
        balances.put(msg.caller, from_balance - amount);
        ignore addRecord(
            msg.caller, "burn",
            [
                ("from", #Principal(msg.caller)),
                ("amount", #U64(u64(amount))),
                ("fee", #U64(u64(0)))
            ]
        );
        return #Ok(txcounter);
    };

    public query func logo() : async Text {
        return logo_;
    };

    public query func name() : async Text {
        return name_;
    };

    public query func symbol() : async Text {
        return symbol_;
    };

    public query func decimals() : async Nat8 {
        return decimals_;
    };

    public query func totalSupply() : async Nat {
        return totalSupply_;
    };

    public query func getTokenFee() : async Nat {
        return fee;
    };

    public query func balanceOf(who: Principal) : async Nat {
        return _balanceOf(who);
    };

    public query func allowance(owner: Principal, spender: Principal) : async Nat {
        return _allowance(owner, spender);
    };

    public query func getMetadata() : async Metadata {
        return {
            logo = logo_;
            name = name_;
            symbol = symbol_;
            decimals = decimals_;
            totalSupply = totalSupply_;
            owner = owner_;
            fee = fee;
        };
    };

    /// Get transaction history size
    public query func historySize() : async Nat {
        return txcounter;
    };

    /*
    *   Optional interfaces:
    *       setName/setLogo/setFee/setFeeTo/setOwner
    *       getUserTransactionsAmount/getUserTransactions
    *       getTokenInfo/getHolders/getUserApprovals
    */
    public shared(msg) func setName(name: Text) {
        assert(msg.caller == owner_);
        name_ := name;
    };

    public shared(msg) func setLogo(logo: Text) {
        assert(msg.caller == owner_);
        logo_ := logo;
    };

    public shared(msg) func setFeeTo(to: Principal) {
        assert(msg.caller == owner_);
        feeTo := to;
    };

    public shared(msg) func setFee(_fee: Nat) {
        assert(msg.caller == owner_);
        fee := _fee;
    };

    public shared(msg) func setOwner(_owner: Principal) {
        assert(msg.caller == owner_);
        owner_ := _owner;
    };

    public type TokenInfo = {
        metadata: Metadata;
        feeTo: Principal;
        // status info
        historySize: Nat;
        deployTime: Time.Time;
        holderNumber: Nat;
        cycles: Nat;
    };
    public query func getTokenInfo(): async TokenInfo {
        {
            metadata = {
                logo = logo_;
                name = name_;
                symbol = symbol_;
                decimals = decimals_;
                totalSupply = totalSupply_;
                owner = owner_;
                fee = fee;
            };
            feeTo = feeTo;
            historySize = txcounter;
            deployTime = genesis.timestamp;
            holderNumber = balances.size();
            cycles = ExperimentalCycles.balance();
        }
    };

    public query func getHolders(start: Nat, limit: Nat) : async [(Principal, Nat)] {
        let temp =  Iter.toArray(balances.entries());
        func order (a: (Principal, Nat), b: (Principal, Nat)) : Order.Order {
            return Nat.compare(b.1, a.1);
        };
        let sorted = Array.sort(temp, order);
        let limit_: Nat = if(start + limit > temp.size()) {
            temp.size() - start
        } else {
            limit
        };
        let res = Array.init<(Principal, Nat)>(limit_, (owner_, 0));
        for (i in Iter.range(0, limit_ - 1)) {
            res[i] := sorted[i+start];
        };
        return Array.freeze(res);
    };

    public query func getAllowanceSize() : async Nat {
        var size : Nat = 0;
        for ((k, v) in allowances.entries()) {
            size += v.size();
        };
        return size;
    };

    public query func getUserApprovals(who : Principal) : async [(Principal, Nat)] {
        switch (allowances.get(who)) {
            case (?allowance_who) {
                return Iter.toArray(allowance_who.entries());
            };
            case (_) {
                return [];
            };
        }
    };

    /*
    * upgrade functions
    */
    system func preupgrade() {
        balanceEntries := Iter.toArray(balances.entries());
        var size : Nat = allowances.size();
        var temp : [var (Principal, [(Principal, Nat)])] = Array.init<(Principal, [(Principal, Nat)])>(size, (owner_, []));
        size := 0;
        for ((k, v) in allowances.entries()) {
            temp[size] := (k, Iter.toArray(v.entries()));
            size += 1;
        };
        allowanceEntries := Array.freeze(temp);
    };

    system func postupgrade() {
        balances := HashMap.fromIter<Principal, Nat>(balanceEntries.vals(), 1, Principal.equal, Principal.hash);
        balanceEntries := [];
        for ((k, v) in allowanceEntries.vals()) {
            let allowed_temp = HashMap.fromIter<Principal, Nat>(v.vals(), 1, Principal.equal, Principal.hash);
            allowances.put(k, allowed_temp);
        };
        allowanceEntries := [];
    };

    public query func http_request(request : Http.Request) : async Http.Response {
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));
        if (path.size() == 2) {
            switch (path[0]) {
                case ("balance") return _natResponse(_balanceOf(Principal.fromText(path[1])));
                case (_) return return Http.BAD_REQUEST();
            };
        } else {
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
};
