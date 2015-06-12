defmodule Esqlite3.Test do 
	use ExUnit.Case, async: true

	test "esqlite3 tests" do
		db_path = 'test/esqlite3_test.db'
		File.rm(db_path)
    {:ok, db} = :esqlite3.open(db_path)
    {:ok, db_copy} = :esqlite3.open(db_path)

    :ok = :esqlite3.exec("create table test_table(col1 varchar(10), col2 int);", db)
    :ok = :esqlite3.exec("begin;", db)
		{:ok, st} = :esqlite3.prepare("insert into test_table (col1, col2) values(?1, ?2)", db)
		:ok = :esqlite3.bind(st, [:a, 1])
    :"$done" = :esqlite3.step(st)
    {:ok, 1} = :esqlite3.changes(db)
 		:esqlite3.bind(st, [:b, 2])
    :esqlite3.step(st)
    {:ok, 1} = :esqlite3.changes(db)
 		:esqlite3.bind(st, ["c", 3])
    :esqlite3.step(st)
    {:ok, 1} = :esqlite3.changes(db)
    [{"a", 1}, {"b", 2}, {"c", 3}] = :esqlite3.q("select * from test_table order by col1;", db)
    [] = :esqlite3.q("select * from test_table order by col1;", db_copy)
    :ok = :esqlite3.exec("commit;", db)

    [{"a", 1}, {"b", 2}, {"c", 3}] = :esqlite3.q("select * from test_table order by col1;", db)
    [{"a", 1}, {"b", 2}, {"c", 3}] = :esqlite3.q("select * from test_table order by col1;", db_copy)

    {:ok, st} = :esqlite3.prepare("select * from test_table where col1=?1", db)
 		:ok = :esqlite3.bind(st, ["c"])
    {:row, {"c", 3}} = :esqlite3.step(st)
    #:"$done" = :esqlite3.step(st)
		#:ok = :esqlite3.finalize(st)
		
    {:col1, :col2} =  :esqlite3.column_names(st)

    :ok = :esqlite3.exec("delete from test_table;", db)
    [] = :esqlite3.q("select * from test_table order by col1;", db)
    [] = :esqlite3.q("select * from test_table order by col1;", db_copy)
		
		:ok = :esqlite3.close(db)
		:ok = :esqlite3.close(db_copy)

	end
end	
