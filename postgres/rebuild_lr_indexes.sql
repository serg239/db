CREATE OR REPLACE FUNCTION rebuild_lr_indexes
(
  parent_id INTEGER, 
  l_idx     INTEGER
) 
RETURNS INTEGER 
AS
$body$
/*
Input:
  parent_id  - ID of the Parent Element
  l_idx      - Left Index
Output:
  Last r_idx value
Notes:
  The Recursive, Tree Traversal Algorithm
Example (starting from 'root' as parent):
  SELECT rebild_lr_indexes(0, 1); 
*/  
DECLARE
  r_idx       INTEGER; 
  cls_rec     RECORD;
  i           INTEGER;
  sql_stmt    TEXT;
  child_array INTEGER[];
  class_id    INTEGER;
  child_nums  INTEGER;
BEGIN  
  r_idx := l_idx + 1;  -- Right Index of the Node is the Left Index + 1
  
  -- Get all childs of the Parent
  child_array := '{}';
  child_nums := 0;
  sql_stmt := 'SELECT class_id FROM metrics.classes WHERE parent_id = '||quote_literal(parent_id)||' ORDER BY class_id';
  FOR cls_rec IN EXECUTE sql_stmt LOOP
    child_array[child_nums+1] := cls_rec.class_id;
    child_nums := child_nums + 1;
  END LOOP;
  
  -- Recursive execution of this function for each Child of this Parent (Node)
  -- r_idx is the current right value which is incremented by the rebuild_indexes function
  IF (child_nums > 0) THEN
    FOR i IN 0..child_nums LOOP
      class_id := child_array[i+1];
      IF class_id > 0 THEN 
        SELECT rebuild_lr_indexes (class_id, r_idx) INTO r_idx;
      END IF;  
    END LOOP;
  END IF;    
  
  -- We've got the left index, and now that we've processes 
  -- the children of this node, we also know the right index 
  sql_stmt = 'UPDATE metrics.classes SET '||
             'l_idx = '||l_idx||
             ', r_idx = '||r_idx||' '||
             'WHERE class_id = '||parent_id;
  -- RAISE NOTICE '%', sql_stmt;
  EXECUTE sql_stmt;
  -- RAISE NOTICE '% <- % -> %', l_idx, parent_id, r_idx;
  RETURN r_idx + 1;
END;
$body$
LANGUAGE 'plpgsql' 
VOLATILE CALLED ON NULL INPUT 
SECURITY INVOKER;

COMMENT ON FUNCTION rebuild_lr_indexes
(
  parent_id INTEGER, 
  l_idx     INTEGER
)
IS 'The Recursive, Tree Traversal Algorithm of the L-R indexing of the classes table.';