// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Donees {
    // 컨트랙트 소유자
    address public owner;

    // 링크 구조체 정의
    struct Link {
        string linkType; // 링크 타입 (예: "X", "Website", "Other")
        string url;      // 링크 URL
    }

    // 프로젝트 구조체 정의
    struct Project {
        uint id;           // 프로젝트 ID
        string[] tags;     // 태그 배열 (예: ["Ecology", "Wildlife"])
        string name;       // 프로젝트 이름
        string descriptionCid; // IPFS CID (설명은 IPFS에 저장)
        Link[] links;      // 링크 배열
        bool exists;       // 프로젝트 존재 여부 (삭제 관리용)
    }

    // 프로젝트를 저장하는 매핑 (ID => Project)
    mapping(uint => Project) public projects;
    // 프로젝트 ID 카운터
    uint public projectCount;

    // 태그별 프로젝트 ID 목록 (태그 필터링용)
    mapping(string => uint[]) private tagToProjectIds;
    // 모든 태그 목록
    string[] private allTags;
    // 태그 존재 여부 확인용 매핑
    mapping(string => bool) private tagExists;

    // 이벤트 정의
    event ProjectAdded(uint indexed projectId, string name, string descriptionCid);
    event ProjectUpdated(uint indexed projectId, string name, string descriptionCid);
    event ProjectDeleted(uint indexed projectId);
    event TagAdded(string tag);
    event TagDeleted(string tag);
    event TagUpdated(string oldTag, string newTag);

    // 생성자: 컨트랙트 배포자를 소유자로 설정하고 기본 태그 추가
    constructor() {
        owner = msg.sender;
        projectCount = 0;

        // 기본 태그 추가: "Ecology"와 "Wildlife"
        allTags.push("Ecology");
        tagExists["Ecology"] = true;
        emit TagAdded("Ecology");

        allTags.push("Wildlife");
        tagExists["Wildlife"] = true;
        emit TagAdded("Wildlife");
    }

    // 소유자만 실행할 수 있는 modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // 입력 검증 modifier
    modifier validString(string memory _str, uint _maxLength) {
        require(bytes(_str).length > 0, "String cannot be empty");
        require(bytes(_str).length <= _maxLength, "String exceeds maximum length");
        _;
    }

    // 태그 목록 보기 함수
    function getAllTags() public view returns (string[] memory) {
        return allTags;
    }

    // 태그 추가 함수
    function addTag(string memory _tag) public onlyOwner validString(_tag, 50) {
        require(!tagExists[_tag], "Tag already exists");
        
        allTags.push(_tag);
        tagExists[_tag] = true;
        
        emit TagAdded(_tag);
    }

    // 태그 삭제 함수
    function deleteTag(string memory _tag) public onlyOwner {
        require(tagExists[_tag], "Tag does not exist");

        // 태그를 사용하는 모든 프로젝트에서 태그 제거
        uint[] memory projectIds = tagToProjectIds[_tag];
        for (uint i = 0; i < projectIds.length; i++) {
            uint projectId = projectIds[i];
            if (projects[projectId].exists) {
                Project storage project = projects[projectId];
                for (uint j = 0; j < project.tags.length; j++) {
                    if (keccak256(abi.encodePacked(project.tags[j])) == keccak256(abi.encodePacked(_tag))) {
                        project.tags[j] = project.tags[project.tags.length - 1];
                        project.tags.pop();
                        break;
                    }
                }
            }
        }

        // 태그 목록에서 제거
        for (uint i = 0; i < allTags.length; i++) {
            if (keccak256(abi.encodePacked(allTags[i])) == keccak256(abi.encodePacked(_tag))) {
                allTags[i] = allTags[allTags.length - 1];
                allTags.pop();
                break;
            }
        }

        // 태그 관련 매핑 업데이트
        delete tagToProjectIds[_tag];
        tagExists[_tag] = false;

        emit TagDeleted(_tag);
    }

    // 태그 수정 함수
    function updateTag(string memory _oldTag, string memory _newTag) 
        public 
        onlyOwner 
        validString(_oldTag, 50) 
        validString(_newTag, 50) 
    {
        require(tagExists[_oldTag], "Old tag does not exist");
        require(!tagExists[_newTag], "New tag already exists");

        // 태그 목록에서 업데이트
        for (uint i = 0; i < allTags.length; i++) {
            if (keccak256(abi.encodePacked(allTags[i])) == keccak256(abi.encodePacked(_oldTag))) {
                allTags[i] = _newTag;
                break;
            }
        }

        // 태그를 사용하는 모든 프로젝트에서 태그 업데이트
        uint[] memory projectIds = tagToProjectIds[_oldTag];
        for (uint i = 0; i < projectIds.length; i++) {
            uint projectId = projectIds[i];
            if (projects[projectId].exists) {
                Project storage project = projects[projectId];
                for (uint j = 0; j < project.tags.length; j++) {
                    if (keccak256(abi.encodePacked(project.tags[j])) == keccak256(abi.encodePacked(_oldTag))) {
                        project.tags[j] = _newTag;
                    }
                }
            }
        }

        // 태그 매핑 업데이트
        tagToProjectIds[_newTag] = tagToProjectIds[_oldTag];
        delete tagToProjectIds[_oldTag];
        tagExists[_oldTag] = false;
        tagExists[_newTag] = true;

        emit TagUpdated(_oldTag, _newTag);
    }

    // 프로젝트 추가 함수
    function addProject(
        string[] memory _tags,
        string memory _name,
        string memory _descriptionCid,
        Link[] memory _links
    ) 
        public 
        onlyOwner 
        validString(_name, 100) 
        validString(_descriptionCid, 46)
    {
        // 태그 검증: 모든 태그가 존재하는지 확인
        require(_tags.length > 0, "At least one tag is required");
        for (uint i = 0; i < _tags.length; i++) {
            require(tagExists[_tags[i]], "Tag does not exist");
            require(bytes(_tags[i]).length > 0 && bytes(_tags[i]).length <= 50, "Invalid tag length");
        }

        // 링크 검증
        for (uint i = 0; i < _links.length; i++) {
            require(bytes(_links[i].linkType).length <= 20, "Link type too long");
            require(bytes(_links[i].url).length <= 200, "Link URL too long");
        }

        // 프로젝트 추가
        uint projectId = projectCount;
        Project storage newProject = projects[projectId];
        newProject.id = projectId;
        newProject.name = _name;
        newProject.descriptionCid = _descriptionCid;
        newProject.exists = true;

        // 태그 배열 수동 복사
        for (uint i = 0; i < _tags.length; i++) {
            newProject.tags.push(_tags[i]);
        }

        // 링크 배열 수동 복사
        for (uint i = 0; i < _links.length; i++) {
            newProject.links.push(Link({
                linkType: _links[i].linkType,
                url: _links[i].url
            }));
        }

        // 태그별 프로젝트 ID 매핑
        for (uint i = 0; i < _tags.length; i++) {
            tagToProjectIds[_tags[i]].push(projectId);
        }

        projectCount++;
        emit ProjectAdded(projectId, _name, _descriptionCid);
    }

    // 모든 프로젝트 조회 함수
    function getAllProjects() public view returns (Project[] memory) {
        uint activeCount = 0;
        for (uint i = 0; i < projectCount; i++) {
            if (projects[i].exists) {
                activeCount++;
            }
        }

        Project[] memory activeProjects = new Project[](activeCount);
        uint index = 0;
        for (uint i = 0; i < projectCount; i++) {
            if (projects[i].exists) {
                activeProjects[index] = projects[i];
                index++;
            }
        }
        return activeProjects;
    }

    // 특정 프로젝트 조회 함수
    function getProject(uint _projectId) public view returns (Project memory) {
        require(_projectId < projectCount, "Project ID out of range");
        require(projects[_projectId].exists, "Project does not exist");
        return projects[_projectId];
    }

    // 프로젝트 수정 함수 (수정됨)
    function updateProject(
        uint _projectId,
        string[] memory _tags,
        string memory _name,
        string memory _descriptionCid,
        Link[] memory _links
    ) 
        public 
        onlyOwner 
        validString(_name, 100) 
        validString(_descriptionCid, 46)
    {
        require(_projectId < projectCount, "Project ID out of range");
        require(projects[_projectId].exists, "Project does not exist");

        // 태그 검증: 모든 태그가 존재하는지 확인
        require(_tags.length > 0, "At least one tag is required");
        for (uint i = 0; i < _tags.length; i++) {
            require(tagExists[_tags[i]], "Tag does not exist");
            require(bytes(_tags[i]).length > 0 && bytes(_tags[i]).length <= 50, "Invalid tag length");
        }

        // 링크 검증 (수정됨: 올바른 require 문으로 복원)
        for (uint i = 0; i < _links.length; i++) {
            require(bytes(_links[i].linkType).length <= 20, "Link type too long");
            require(bytes(_links[i].url).length <= 200, "Link URL too long");
        }

        // 기존 태그 매핑 제거
        for (uint i = 0; i < projects[_projectId].tags.length; i++) {
            string memory tag = projects[_projectId].tags[i];
            uint[] storage projectIds = tagToProjectIds[tag];
            for (uint j = 0; j < projectIds.length; j++) {
                if (projectIds[j] == _projectId) {
                    projectIds[j] = projectIds[projectIds.length - 1];
                    projectIds.pop();
                    break;
                }
            }
        }

        // 프로젝트 업데이트
        Project storage project = projects[_projectId];
        project.name = _name;
        project.descriptionCid = _descriptionCid;

        // 기존 태그 배열 비우기
        while (project.tags.length > 0) {
            project.tags.pop();
        }
        // 새 태그 배열 수동 복사
        for (uint i = 0; i < _tags.length; i++) {
            project.tags.push(_tags[i]);
        }

        // 기존 링크 배열 비우기
        while (project.links.length > 0) {
            project.links.pop();
        }
        // 새 링크 배열 수동 복사
        for (uint i = 0; i < _links.length; i++) {
            project.links.push(Link({
                linkType: _links[i].linkType,
                url: _links[i].url
            }));
        }

        // 새로운 태그 매핑 추가
        for (uint i = 0; i < _tags.length; i++) {
            tagToProjectIds[_tags[i]].push(_projectId);
        }

        emit ProjectUpdated(_projectId, _name, _descriptionCid);
    }

    // 프로젝트 삭제 함수
    function deleteProject(uint _projectId) public onlyOwner {
        require(_projectId < projectCount, "Project ID out of range");
        require(projects[_projectId].exists, "Project does not exist");

        // 태그 매핑 제거
        for (uint i = 0; i < projects[_projectId].tags.length; i++) {
            string memory tag = projects[_projectId].tags[i];
            uint[] storage projectIds = tagToProjectIds[tag];
            for (uint j = 0; j < projectIds.length; j++) {
                if (projectIds[j] == _projectId) {
                    projectIds[j] = projectIds[projectIds.length - 1];
                    projectIds.pop();
                    break;
                }
            }
        }

        // 프로젝트 삭제 (exists를 false로 설정)
        projects[_projectId].exists = false;
        emit ProjectDeleted(_projectId);
    }

    // 프로젝트 이름으로 검색 함수
    function searchProjectsByName(string memory _name) public view returns (Project[] memory) {
        uint matchCount = 0;
        for (uint i = 0; i < projectCount; i++) {
            if (projects[i].exists && _stringContains(projects[i].name, _name)) {
                matchCount++;
            }
        }

        Project[] memory matches = new Project[](matchCount);
        uint index = 0;
        for (uint i = 0; i < projectCount; i++) {
            if (projects[i].exists && _stringContains(projects[i].name, _name)) {
                matches[index] = projects[i];
                index++;
            }
        }
        return matches;
    }

    // 단일 태그로 프로젝트 필터링 함수
    function filterProjectsByTag(string memory _tag) public view returns (Project[] memory) {
        uint[] memory projectIds = tagToProjectIds[_tag];
        uint matchCount = 0;

        for (uint i = 0; i < projectIds.length; i++) {
            uint projectId = projectIds[i];
            if (projects[projectId].exists) {
                matchCount++;
            }
        }

        Project[] memory matches = new Project[](matchCount);
        uint index = 0;
        for (uint i = 0; i < projectIds.length; i++) {
            uint projectId = projectIds[i];
            if (projects[projectId].exists) {
                matches[index] = projects[projectId];
                index++;
            }
        }
        return matches;
    }

    // 다중 태그로 프로젝트 필터링 함수
    function filterProjectsByTags(string[] memory _tags) public view returns (Project[] memory) {
        if (_tags.length == 0) {
            return getAllProjects();
        }

        uint[] memory candidateIds = tagToProjectIds[_tags[0]];
        uint[] memory filteredIds = new uint[](projectCount);
        uint filteredCount = 0;

        for (uint i = 0; i < candidateIds.length; i++) {
            uint projectId = candidateIds[i];
            if (!projects[projectId].exists) continue;

            bool matchesAllTags = true;
            for (uint j = 1; j < _tags.length; j++) {
                bool hasTag = false;
                for (uint k = 0; k < projects[projectId].tags.length; k++) {
                    if (keccak256(abi.encodePacked(projects[projectId].tags[k])) == keccak256(abi.encodePacked(_tags[j]))) {
                        hasTag = true;
                        break;
                    }
                }
                if (!hasTag) {
                    matchesAllTags = false;
                    break;
                }
            }

            if (matchesAllTags) {
                filteredIds[filteredCount] = projectId;
                filteredCount++;
            }
        }

        Project[] memory matches = new Project[](filteredCount);
        for (uint i = 0; i < filteredCount; i++) {
            matches[i] = projects[filteredIds[i]];
        }
        return matches;
    }

    // 문자열 포함 여부 확인 (검색용 헬퍼 함수)
    function _stringContains(string memory _str, string memory _substr) private pure returns (bool) {
        bytes memory strBytes = bytes(_str);
        bytes memory substrBytes = bytes(_substr);

        if (substrBytes.length == 0) return true;
        if (strBytes.length < substrBytes.length) return false;

        for (uint i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}