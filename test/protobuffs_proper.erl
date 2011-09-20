%%%-------------------------------------------------------------------
%%% File    : protobuffs_eqc.erl
%%% Author  : David AAberg <david_ab@RB-DAVIDAB01>
%%% Description :
%%%
%%% Created :  5 Aug 2010 by David AAberg <david_ab@RB-DAVIDAB01>
%%%-------------------------------------------------------------------
-module(protobuffs_proper).

-include_lib("proper/include/proper.hrl").

-compile(export_all).

utf8char() ->
    union([integer(0, 36095), integer(57344, 65533),
	   integer(65536, 1114111)]).

utf8string() -> list(utf8char()).

uint32() -> choose(0, 4294967295).

sint32() -> choose(-2147483648, 2147483647).

uint64() -> choose(0, 18446744073709551615).

sint64() ->
    choose(-9223372036854775808, 9223372036854775807).

value() ->
    oneof([{real(), double}, {real(), float}, {nan, float},
	   {infinity, float}, {'-infinity', float}, {nan, double},
	   {infinity, double}, {'-infinity', double},
	   {uint32(), uint32}, {uint64(), uint64},
	   {sint32(), sint32}, {sint64(), sint64},
	   {uint32(), fixed32}, {uint64(), fixed64},
	   {sint32(), sfixed32}, {sint64(), sfixed64},
	   {sint32(), int32}, {sint64(), int64}, {bool(), bool},
	   {sint32(), enum}, {utf8string(), string},
	   {binary(), bytes}]).

compare_messages(ExpectedMsg, Msg) ->
    lists:foldl(fun ({E, D}, Acc) ->
			compare(E, D) andalso Acc
		end,
		true,
		lists:zip(tuple_to_list(ExpectedMsg),
			  tuple_to_list(Msg))).

compare(A, A) -> true;
compare([A], B) -> compare(A, B);
compare(A, [B]) -> compare(A, B);
compare(A, B) when is_tuple(A), is_tuple(B) ->
    compare(tuple_to_list(A), tuple_to_list(B));
compare([A | RA], [B | RB]) ->
    compare(A, B) andalso compare(RA, RB);
compare(A, B) when is_float(A), is_float(B) ->
    <<A32:32/little-float>> = <<A:32/little-float>>,
    <<B32:32/little-float>> = <<B:32/little-float>>,
    if A =:= B -> true;
       A32 =:= B32 -> true;
       true -> false
    end;
compare(_, undefined) -> true;
compare(undefined, _) -> true;
compare(_, _) -> false.

proper_protobuffs() ->
    ?FORALL({FieldID, {Value, Type}},
	    {?SUCHTHAT(I, (uint32()), (I =< 1073741823)), value()},
	    begin
	      case Type of
		float when is_float(Value) ->
		    Encoded = protobuffs:encode(FieldID, Value, Type),
		    {{FieldID, Float}, <<>>} = protobuffs:decode(Encoded,
								 Type),
		    <<Value32:32/little-float>> = <<Value:32/little-float>>,
		    Float =:= Value32;
		_Else ->
		    Encoded = protobuffs:encode(FieldID, Value, Type),
		    {{FieldID, Value}, <<>>} ==
		      protobuffs:decode(Encoded, Type)
	      end
	    end).

proper_protobuffs_packed() ->
    ?FORALL({FieldID, {Values, Type}},
	    {?SUCHTHAT(I, (uint32()), (I =< 1073741823)),
	     oneof([{non_empty(list(uint32())), uint32},
		    {non_empty(list(uint64())), uint64},
		    {non_empty(list(sint32())), sint32},
		    {non_empty(list(sint64())), sint64},
		    {non_empty(list(sint32())), int32},
		    {non_empty(list(sint64())), int64},
		    {non_empty(list(bool())), bool},
		    {non_empty(list(real())), double},
		    {non_empty(list(real())), float}])},
	    begin
		case Type of
		    float ->
			Encoded = protobuffs:encode_packed(FieldID, Values, Type),
			{{FieldID, DecodedValues}, <<>>} =
			    protobuffs:decode_packed(Encoded, Type),
			lists:all(fun ({Expected, Result}) ->
					  <<Expected32:32/little-float>> =
					      <<Expected:32/little-float>>,
					  Expected32 =:= Result
				  end,
				  lists:zip(Values, DecodedValues));
		    _Else ->
			Encoded = protobuffs:encode_packed(FieldID, Values,
							   Type),
			Decoded = protobuffs:decode_packed(Encoded, Type),
			{{FieldID, Values}, <<>>} == Decoded
		end
	    end).

proper_protobuffs_empty() ->
    ?FORALL({Empty},
	    {{empty, default(undefined, real()),
	      default(undefined, real()),
	      default(undefined, sint32()),
	      default(undefined, sint64()),
	      default(undefined, uint32()),
	      default(undefined, uint64()),
	      default(undefined, sint32()),
	      default(undefined, sint64()),
	      default(undefined, uint32()),
	      default(undefined, uint64()),
	      default(undefined, sint32()),
	      default(undefined, sint64()),
	      default(undefined, bool()),
	      default(undefined, utf8string()),
	      default(undefined, binary()),
	      default(undefined, {empty_emptymessage})}},
	    begin
	      Decoded =
		  empty_pb:decode_empty(empty_pb:encode_empty(Empty)),
	      compare_messages(Empty, Decoded)
	    end).

check_with_default(Expected, Result, undefined, Fun) ->
    Fun(Expected, Result);
check_with_default(undefined, Result, Default, Fun) ->
    Fun(Default, Result);
check_with_default(Expected, Result, _Default, Fun) ->
    Fun(Expected, Result).

proper_protobuffs_hasdefault() ->
    ?FORALL({Withdefault},
	    {{withdefault, default(undefined, real()),
	      default(undefined, real()),
	      default(undefined, sint32()),
	      default(undefined, sint64()),
	      default(undefined, uint32()),
	      default(undefined, uint64()),
	      default(undefined, sint32()),
	      default(undefined, sint64()),
	      default(undefined, uint32()),
	      default(undefined, uint64()),
	      default(undefined, sint32()),
	      default(undefined, sint64()),
	      default(undefined, bool()),
	      default(undefined, utf8string()),
	      default(undefined, utf8string())}},
	    begin
	      Decoded =
		  hasdefault_pb:decode_withdefault(hasdefault_pb:encode_withdefault(Withdefault)),
	      compare_messages(Withdefault, Decoded)
	    end).

location() ->
    Str = utf8string(),
    default(undefined, {location, Str, Str}).

proper_protobuffs_simple() ->
    ?FORALL({Person},
	    {{person, utf8string(), utf8string(), utf8string(),
	      sint32(), location()}},
	    begin
	      Decoded =
		  simple_pb:decode_person(simple_pb:encode_person(Person)),
	      compare_messages(Person, Decoded)
	    end).

phone_type() ->
    Int32 = default(undefined, sint32()),
    {person_phonenumber_phonetype, Int32, Int32, Int32}.

phone_number() ->
    list({person_phonenumber, utf8string(),
	  default(undefined, phone_type())}).

proper_protobuffs_nested1() ->
    ?FORALL({Person},
	    {{person, utf8string(), sint32(),
	      default(undefined, utf8string()), phone_number()}},
	    begin
	      Decoded =
		  nested1_pb:decode_person(nested1_pb:encode_person(Person)),
	      compare_messages(Person, Decoded)
	    end).

innerAA() ->
    {outer_middleaa_inner, sint64(),
     default(undefined, bool())}.

middleAA() ->
    Inner = innerAA(),
    {outer_middleaa, default(undefined, Inner)}.

innerBB() ->
    {outer_middlebb_inner, sint32(),
     default(undefined, bool())}.

middleBB() ->
    Inner = innerBB(),
    {outer_middlebb, default(undefined, Inner)}.

proper_protobuffs_nested2() ->
    ?FORALL({Middle},
	    {{outer, default(undefined, middleAA()),
	      default(undefined, middleBB())}},
	    begin
	      Decoded =
		  nested2_pb:decode_outer(nested2_pb:encode_outer(Middle)),
	      compare_messages(Middle, Decoded)
	    end).

inner() ->
    {outer_middle_inner, default(undefined, bool())}.

other() -> {outer_other, default(undefined, bool())}.

middle() ->
    Inner = inner(),
    Other = other(),
    {outer_middle, Inner, Other}.

proper_protobuffs_nested3() ->
    ?FORALL({Middle},
	    {default({outer, undefined}, {outer, middle()})},
	    begin
	      Decoded =
		  nested3_pb:decode_outer(nested3_pb:encode_outer(Middle)),
	      compare_messages(Middle, Decoded)
	    end).

proper_protobuffs_nested4() ->
    ?FORALL({Middle},
	    {default({outer, undefined}, {outer, middle()})},
	    begin
	      Decoded =
		  nested4_pb:decode_outer(nested4_pb:encode_outer(Middle)),
	      compare_messages(Middle, Decoded)
	    end).

first_inner() ->
    {first_inner, default(undefined, bool())}.

proper_protobuffs_nested5() ->
    ?FORALL(Inner,
	    oneof([default({first, undefined}, {first, first_inner()}),
		    {second, first_inner()}]),
	    begin
		case element(1,Inner) of
		    first ->
			Decoded = nested5_pb:decode_first(nested5_pb:encode_first(Inner)),
			compare_messages(Inner, Decoded);
		    second ->
			Decoded = nested5_pb:decode_second(nested5_pb:encode_second(Inner)),
			compare_messages(Inner, Decoded)
		end
	    end).

enum_value() -> oneof([value1, value2]).

proper_protobuffs_enum() ->
    ?FORALL({Middle},
	    {default({enummsg, undefined},
		     {enummsg, enum_value()})},
	    begin
	      Decoded =
		  enum_pb:decode_enummsg(enum_pb:encode_enummsg(Middle)),
	      compare_messages(Middle, Decoded)
	    end).

enum_outside_value() -> oneof(['FIRST', 'SECOND']).

proper_protobuffs_enum_outside() ->
    ?FORALL({Middle},
	    {default({enumuser, undefined},
		     {enumuser, enum_outside_value()})},
	    begin
	      Decoded =
		  enum_outside_pb:decode_enumuser(enum_outside_pb:encode_enumuser(Middle)),
	      compare_messages(Middle, Decoded)
	    end).

proper_protobuffs_extensions() ->
    ?FORALL({Middle},
	    {default({extendable}, {maxtendable})},
	    begin
	      DecodeFunc = list_to_atom("decode_" ++
					  atom_to_list(element(1, Middle))),
	      Decoded =
		  extensions_pb:DecodeFunc(extensions_pb:encode(Middle)),
	      compare_messages(Middle, Decoded)
	    end).

address_phone_number() ->
    list({person_phonenumber, utf8string(),
	  default(undefined, oneof(['HOME', 'WORK', 'MOBILE']))}).

addressbook() ->
    list({person, utf8string(), sint32(), utf8string(),
	  default(undefined, address_phone_number())}).

proper_protobuffs_addressbook() ->
    ?FORALL({Addressbook},
	    {default({addressbook, undefined},
		     {addressbook, addressbook()})},
	    begin
	      Decoded =
		  addressbook_pb:decode_addressbook(addressbook_pb:encode_addressbook(Addressbook)),
	      compare_messages(Addressbook, Decoded)
	    end).

repeater_location() ->
    {location, utf8string(), utf8string()}.

repeater_person() ->
    {person, utf8string(), utf8string(), utf8string(),
     sint32(), default(undefined, list(utf8string())),
     default(undefined, list(repeater_location())),
     list(uint32())}.

proper_protobuffs_repeater() ->
    ?FORALL({Repeater}, {repeater_person()},
	    begin
	      Decoded =
		  repeater_pb:decode_person(repeater_pb:encode_person(Repeater)),
	      compare_messages(Repeater, Decoded)
	    end).

proper_protobuffs_packed_repeated() ->
    ?FORALL({Repeater}, {repeater_person()},
	    begin
	      Decoded =
		  packed_repeated_pb:decode_person(packed_repeated_pb:encode_person(Repeater)),
	      compare_messages(Repeater, Decoded)
	    end).

special_words() ->
    {message, utf8string(), utf8string(), utf8string(),
     utf8string(), utf8string(), utf8string(), utf8string(),
     utf8string(), utf8string(), utf8string(), utf8string(),
     utf8string(), utf8string(), utf8string(), utf8string(),
     utf8string(), utf8string(), utf8string(), utf8string(),
     utf8string(), utf8string(), utf8string(), utf8string(),
     utf8string(), utf8string(), utf8string(), utf8string(),
     utf8string(), utf8string(), utf8string()}.

proper_protobuffs_special_words() ->
    ?FORALL({SpecialWords}, {special_words()},
	    begin
	      Decoded =
		  special_words_pb:decode_message(special_words_pb:encode_message(SpecialWords)),
	      compare_messages(SpecialWords, Decoded)
	    end).

proper_protobuffs_import() ->
    ?FORALL({Imported},
	    {default({foo, {imported, utf8string()}},
		     {foo, undefined})},
	    begin
	      Decoded =
		  import_pb:decode_foo(import_pb:encode(Imported)),
	      compare_messages(Imported, Decoded)
	    end).

single() -> {message, uint32()}.

proper_protobuffs_single() ->
    ?FORALL(Single, single(),
	    begin
	      Decoded =
		  single_pb:decode_message(single_pb:encode_message(Single)),
	      compare_messages(Single, Decoded)
	    end).

proper_protobuffs_extend() ->
    ?FORALL(Extend,
	    default({extendable, sint32()},
		    {extendable, undefined}),
	    begin
		Decoded =
		    extend_pb:decode_extendable(extend_pb:encode_extendable(Extend)),
		compare_messages(Extend, Decoded)
	    end).

proper_protobuffs_service() ->
    %Don't handel service tag for the moment testing no errors and that the messages works
    ?FORALL(Service,
	    oneof([{serchresponse, default(undefined,string())},
		   {serchrequest, default(undefined,string())}]),
	    begin
		case element(1,Service) of
		    serchresponse -> 
			Decoded = service_pb:decode_serchresponse(
				    service_pb:encode_searchresponce(Service)),
			compare_messages(Service, Decoded);
		    serchrequest ->
			Decoded = service_pb:decode_serchrequest(
				    service_pb:encode_serchrequest(Service)),
			compare_messages(Service, Decoded)
		end
	    end).