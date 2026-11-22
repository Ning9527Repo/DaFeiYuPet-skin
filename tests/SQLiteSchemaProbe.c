#include <sqlite3.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    if(argc!=2) { fputs("usage: probe database\n",stderr); return 2; }
    sqlite3 *db=NULL;
    int rc=sqlite3_open_v2(argv[1],&db,SQLITE_OPEN_READONLY|SQLITE_OPEN_URI,NULL);
    if(rc!=SQLITE_OK) { fprintf(stderr,"open failed: %s\n",db?sqlite3_errmsg(db):"unknown"); if(db) sqlite3_close(db); return 3; }
    sqlite3_stmt *stmt=NULL;
    rc=sqlite3_prepare_v2(db,"SELECT name, type, sql FROM sqlite_master WHERE type IN ('table','view') ORDER BY name",-1,&stmt,NULL);
    if(rc!=SQLITE_OK) { fprintf(stderr,"schema failed: %s\n",sqlite3_errmsg(db)); sqlite3_close(db); return 4; }
    while((rc=sqlite3_step(stmt))==SQLITE_ROW) {
        const unsigned char *name=sqlite3_column_text(stmt,0);
        const unsigned char *type=sqlite3_column_text(stmt,1);
        const unsigned char *sql=sqlite3_column_text(stmt,2);
        if(name && type) printf("%s %s\n",type,name);
        if(sql && name && strcmp((const char *)name,"lyrics")==0)
            printf("  schema: %s\n",sql);
    }
    sqlite3_finalize(stmt);
    if(rc!=SQLITE_DONE) { sqlite3_close(db); return 5; }
    rc=sqlite3_prepare_v2(db,"SELECT type, count(*), min(lrcx), max(lrcx) FROM lyrics GROUP BY type ORDER BY type LIMIT 20",-1,&stmt,NULL);
    if(rc!=SQLITE_OK) { sqlite3_close(db); return 6; }
    while((rc=sqlite3_step(stmt))==SQLITE_ROW)
        printf("lyric group: type=%d entries=%d lrcx range=%lld..%lld\n",sqlite3_column_int(stmt,0),sqlite3_column_int(stmt,1),sqlite3_column_int64(stmt,2),sqlite3_column_int64(stmt,3));
    sqlite3_finalize(stmt);
    sqlite3_close(db);
    return rc==SQLITE_DONE?0:7;
}
