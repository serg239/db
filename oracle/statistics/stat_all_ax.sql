REM  SCRIPT
REM    stat_all_ax.sql
REM  TITLE
REM    Table, index and column statsistics
REM  HINT
REM    List the table, index and column statsistics
REM    # Script Description:
REM    =====================
REM    1. Uses the new 8i DBMS_STATS package to list the table, 
REM    index and column statsistics.

PROMPT
ACCEPT ownr PROMPT "Table owner (Enter for <All>): "
ACCEPT tbln PROMPT "Table name (Enter for <All>): "
PROMPT

DECLARE 
  CURSOR get_tbl 
  IS 
    SELECT owner,
           table_name 
      FROM all_tables 
     WHERE owner      LIKE UPPER('%&ownr%')
       AND table_name LIKE UPPER('%&tbln%');

  CURSOR get_indx 
  IS 
    SELECT owner, 
           index_name 
      FROM all_indexes
     WHERE owner      LIKE UPPER('%&ownr%')
       AND table_name LIKE UPPER('%&tbln%');

  CURSOR get_col 
  IS 
    SELECT owner,
           table_name,
           column_name 
      FROM all_tab_columns
     WHERE owner      LIKE UPPER('%&ownr%')
       AND table_name LIKE UPPER('%&tbln%');

  t_numrows  NUMBER;
  t_numblks  NUMBER;
  t_avgrlen  NUMBER;
  i_numrows  NUMBER;
  i_numlblks NUMBER;
  i_numdist  NUMBER;
  i_avglblk  NUMBER;
  i_avgdblk  NUMBER;
  i_clstfct  NUMBER;
  i_indlevel NUMBER;
  c_distcnt  NUMBER;
  c_density  NUMBER;
  c_nullcnt  NUMBER;
  c_srec     DBMS_STATS.STATREC;
  c_avgclen  NUMBER;
BEGIN
  FOR tbl IN get_tbl 
  LOOP
    DBMS_STATS.GET_TABLE_STATS (ownname => tbl.owner, 
                                tabname => tbl.table_name, 
                                numrows => t_numrows, 
                                numblks => t_numblks, 
                                avgrlen => t_avgrlen);
    DBMS_OUTPUT.PUT_LINE('Table Stats: '||RPAD(tbl.owner||'.'||tbl.table_name, 40, ' ')||' NUM_ROWS    '||t_numrows);
    DBMS_OUTPUT.PUT_LINE('Table Stats: '||RPAD(tbl.owner||'.'||tbl.table_name, 40, ' ')||' BLOCKS      '||t_numblks);
    DBMS_OUTPUT.PUT_LINE('Table Stats: '||RPAD(tbl.owner||'.'||tbl.table_name, 40, ' ')||' AVG_ROW_LEN '||t_avgrlen);
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 40, '-'));

    FOR indx IN get_indx 
    LOOP
       DBMS_STATS.GET_INDEX_STATS(ownname  => indx.owner, 
                                  indname  => indx.index_name, 
                                  numrows  => i_numrows, 
                                  numlblks => i_numlblks, 
                                  numdist  => i_numdist, 
                                  avglblk  => i_avglblk, 
                                  avgdblk  => i_avgdblk, 
                                  clstfct  => i_clstfct, 
                                  indlevel => i_indlevel);
      DBMS_OUTPUT.PUT_LINE('Index Stats: '||RPAD(indx.owner||'.'||indx.index_name, 40, ' ')||' NUM_ROWS  '||i_numrows);
      DBMS_OUTPUT.PUT_LINE('Index Stats: '||RPAD(indx.owner||'.'||indx.index_name, 40, ' ')||' NUM_LBLKS '||i_numlblks);
      DBMS_OUTPUT.PUT_LINE('Index Stats: '||RPAD(indx.owner||'.'||indx.index_name, 40, ' ')||' NUM_DIST  '||i_numdist);
      DBMS_OUTPUT.PUT_LINE('Index Stats: '||RPAD(indx.owner||'.'||indx.index_name, 40, ' ')||' AVGLBLK   '||i_avglblk);
      DBMS_OUTPUT.PUT_LINE('Index Stats: '||RPAD(indx.owner||'.'||indx.index_name, 40, ' ')||' AVGDBLK   '||i_avgdblk);
      DBMS_OUTPUT.PUT_LINE('Index Stats: '||RPAD(indx.owner||'.'||indx.index_name, 40, ' ')||' CLSTFCT   '||i_clstfct);
      DBMS_OUTPUT.PUT_LINE('Index Stats: '||RPAD(indx.owner||'.'||indx.index_name, 40, ' ')||' IND_LEVEL '||i_indlevel);
      DBMS_OUTPUT.PUT_LINE(RPAD('-', 40, '-'));
    END LOOP;

    FOR col in get_col 
    LOOP
      DBMS_STATS.GET_COLUMN_STATS(ownname => col.owner, 
                                  tabname => col.table_name, 
                                  colname => col.column_name, 
                                  distcnt => c_distcnt,
                                  density => c_density, 
                                  nullcnt => c_nullcnt, 
                                  srec    => c_srec, 
                                  avgclen => c_avgclen);
      DBMS_OUTPUT.PUT_LINE('Col Stats: '||RPAD(col.table_name||'.'||col.column_name, 64, ' ')||' DISTCNT '||c_distcnt);
      DBMS_OUTPUT.PUT_LINE('Col Stats: '||RPAD(col.table_name||'.'||col.column_name, 64, ' ')||' DENSITY '||c_density);
      DBMS_OUTPUT.PUT_LINE('Col Stats: '||RPAD(col.table_name||'.'||col.column_name, 64, ' ')||' NULLCNT '||c_nullcnt);
      DBMS_OUTPUT.PUT_LINE('Col Stats: '||RPAD(col.table_name||'.'||col.column_name, 64, ' ')||' AVGCLEN '||c_avgclen);
      DBMS_OUTPUT.PUT_LINE(RPAD('-', 40, '-'));
    END LOOP;
    DBMS_OUTPUT.PUT_LINE(RPAD('=', 80, '='));
  END LOOP;

END;
/

UNDEFINE ownr tbln
